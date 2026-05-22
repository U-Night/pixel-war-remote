using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

/// <summary>
/// Gère l'envoi et la réception de messages avec préfixe de longueur. 
/// Pour envoyer un message TCP on l'encapsule:
/// Protocole :  [4 bytes longueur (little-endian)] + [N bytes payload]
/// </summary>
public class TcpMessageFramer {
    private readonly NetworkStream _stream;
    private readonly SemaphoreSlim _writeLock = new(1, 1); // Pour éviter les écritures entrelacées

    // Taille max d'un message (protection contre les attaques/bugs)
    private const int MAX_MESSAGE_SIZE = 1024 * 1024; // 1 MB

    public TcpMessageFramer(NetworkStream stream) {
        _stream = stream ?? throw new ArgumentNullException(nameof(stream));
    }

    /// <summary>
    /// Envoie un message avec son préfixe de longueur (thread-safe)
    /// </summary>
    public async Task SendAsync(string message, CancellationToken ct = default) {
        byte[] payload = Encoding.UTF8.GetBytes(message);

        if (payload.Length > MAX_MESSAGE_SIZE)
            throw new ArgumentException($"Message trop grand : {payload.Length} bytes (max:  {MAX_MESSAGE_SIZE})");

        byte[] lengthPrefix = BitConverter.GetBytes(payload.Length);

        // Lock pour éviter que deux messages s'entrelacent
        await _writeLock.WaitAsync(ct);
        try {
            await _stream.WriteAsync(lengthPrefix, 0, 4, ct);
            await _stream.WriteAsync(payload, 0, payload.Length, ct);
        } finally {
            _writeLock.Release();
        }
    }

    /// <summary>
    /// Lit un message complet.  Retourne null si la connexion est fermée. 
    /// </summary>
    public async Task<string?> ReceiveAsync(CancellationToken ct = default) {
        // --- ÉTAPE 1 :  Lire les 4 bytes de longueur ---
        byte[] lengthBuffer = new byte[4];
        if (!await ReadExactAsync(lengthBuffer, 4, ct))
            return null; // Connexion fermée proprement

        int messageLength = BitConverter.ToInt32(lengthBuffer, 0);

        // Validation de la taille
        if (messageLength <= 0 || messageLength > MAX_MESSAGE_SIZE)
            throw new ProtocolViolationException($"Taille de message invalide : {messageLength}");

        // --- ÉTAPE 2 : Lire le payload complet ---
        byte[] payload = new byte[messageLength];
        if (!await ReadExactAsync(payload, messageLength, ct))
            return null; // Connexion fermée en plein milieu

        return Encoding.UTF8.GetString(payload);
    }

    /// <summary>
    /// Lit EXACTEMENT n bytes. Retourne false si la connexion est fermée.
    /// </summary>
    private async Task<bool> ReadExactAsync(byte[] buffer, int count, CancellationToken ct) {
        int totalRead = 0;

        while (totalRead < count) {
            int bytesRead = await _stream.ReadAsync(
                buffer,
                totalRead,
                count - totalRead,
                ct
            );

            if (bytesRead == 0)
                return false; // Connexion fermée

            totalRead += bytesRead;
        }

        return true;
    }
}

/// <summary>
/// Exception levée quand le protocole n'est pas respecté
/// </summary>
public class ProtocolViolationException : Exception {
    public ProtocolViolationException(string message) : base(message) { }
}