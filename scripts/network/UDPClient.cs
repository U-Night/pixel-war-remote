using System;
using System.Runtime.InteropServices;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;
using System.Buffers;
using Godot;

public partial class UDPClient : Node {
    private UdpClient _udpClient;
    private IPEndPoint _serverEndpoint;
    private uint _sequenceId = 0; // Pour suivre l'ordre des paquets envoyés

    public override void _Ready() {
        // Initialiser le client UDP
        _udpClient = new UdpClient();
        
        // ⚠️ Remplacer par l'IP de ton serveur et le port UDP !
        _serverEndpoint = new IPEndPoint(IPAddress.Parse("127.0.0.1"), 6967); 
    }

    public void SetServerEndpoint(string host, int port) {
        _serverEndpoint = new IPEndPoint(IPAddress.Parse(host), port);
    }

    // Cette méthode agit comme une "passerelle" simple pour GDScript
    // GDScript ne connaît pas IPEndPoint ou Task, donc on lui donne une méthode classique
    public void SendInputFromGDScript(float x, float y, uint userId) {
        // On lance la tâche asynchrone sans bloquer (Fire-and-forget)
        _ = SendPlayerInputAsync(_serverEndpoint, x, y, userId);
    }


    // Implémentation super rapide et standalone du Crc32 (sans package externe)
	private static readonly uint[] Crc32Table = GenerateCrc32Table();
	private static uint[] GenerateCrc32Table() {
		var table = new uint[256];
		uint polynomial = 0xEDB88320;
		for (uint i = 0; i < 256; i++) {
			uint crc = i;
			for (uint j = 8; j > 0; j--) {
				if ((crc & 1) == 1)
					crc = (crc >> 1) ^ polynomial;
				else
					crc >>= 1;
			}
			table[i] = crc;
		}
		return table;
	}

	public static uint ComputeCrc32(ReadOnlySpan<byte> bytes) {
		uint crc = 0xFFFFFFFF;
		for (int i = 0; i < bytes.Length; i++) {
			byte index = (byte)((crc & 0xFF) ^ bytes[i]);
			crc = (crc >> 8) ^ Crc32Table[index];
		}
		return ~crc;
	}

    private int AssemblePlayerInputPacket(byte[] buffer, float x, float y, uint userId) {
        Span<byte> packetBuffer = buffer.AsSpan();

        // 1. On prépare la payload (les inputs)
        UdpPacket.PlayerInputPayload input = new UdpPacket.PlayerInputPayload { X = x, Y = y };
        // On écrit l'input après les 15 octets de l'en-tête
        MemoryMarshal.Write(packetBuffer.Slice(15), in input);

        // 2. On prépare l'en-tête (SANS le CRC pour l'instant)
        ushort totalPacketSize = 15 + 8; // Header (15) + InputPayload (8)
        UdpPacket.PacketHeader header = new UdpPacket.PacketHeader {
            TotalLength = totalPacketSize,
            PacketType = UdpPacket.PacketType.Joystick,
            UserId = userId,
            SequenceId = ++_sequenceId,
            Crc32 = 0 // Vide pour le moment
        };

        // 3. On écrit l'en-tête au début du buffer
        MemoryMarshal.Write(packetBuffer, in header);

        // 4. LE CRC : On calcule l'empreinte sur tout le paquet, SAUF les 4 premiers octets
        uint crc = ComputeCrc32(packetBuffer.Slice(4, totalPacketSize - 4));

        // 5. On écrase les 4 premiers octets (qui étaient à 0) avec le vrai CRC
        BitConverter.TryWriteBytes(packetBuffer.Slice(0, 4), crc);

        return totalPacketSize;
    }

    public async Task SendPlayerInputAsync(IPEndPoint serverEndpoint, float x, float y, uint userId) {
        // ArrayPool permet d'obtenir un buffer sans allocation GC,
        // ce qui est sans danger dans une méthode async.
        byte[] buffer = ArrayPool<byte>.Shared.Rent(1024); 
        
        try {
            int packetSize = AssemblePlayerInputPacket(buffer, x, y, userId);

            // 6. Envoi UDP
            if (_udpClient != null) {
                await _udpClient.SendAsync(buffer, packetSize, serverEndpoint);
            }
        } finally {
            // Toujours restituer le buffer au pool
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }
    
}