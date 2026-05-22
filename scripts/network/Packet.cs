using System;
using System.Text;


/// <summary>
/// Types de paquets supportés par le protocole
/// </summary>
public enum PacketType : ushort {
	// ═══ Système ═══
	Ping = 0x0001,
	Pong = 0x0002,
	Disconnect = 0x0003,

	PlayerJoin = 0x0004,
	PlayerLeave = 0x0005,

	Message = 0x0006,
}

/// <summary>
/// Représente un paquet de données avec son type et son payload
/// 
/// Format binaire :
/// ┌──────────────┬──────────────┬──────────────┬──────────────┐
/// │  TYPE_SIZE   │     TYPE     │  DATA_SIZE   │     DATA     │
/// │   2 bytes    │   N bytes    │   4 bytes    │   M bytes    │
/// └──────────────┴──────────────┴──────────────┴──────────────┘
/// </summary>
public class Packet {
	public PacketType Type { get; }
	public byte[] Data { get; }

	public Packet(PacketType type, byte[] data) {
		Type = type;
		Data = data;
	}

	/// <summary>
	/// Crée un paquet avec des données textuelles
	/// </summary>
	public Packet(PacketType type, string text) : this(type, Encoding.UTF8.GetBytes(text)) { }

	/// <summary>
	/// Crée un paquet sans données
	/// </summary>
	public Packet(PacketType type) : this(type, Array.Empty<byte>()) { }

	/// <summary>
	/// Sérialise le paquet en bytes
	/// </summary>
	public byte[] Serialize() {
		// Type en string pour lisibilité (ex: "PlayerPosition")
		byte[] typeBytes = Encoding.UTF8.GetBytes(Type.ToString());

		// Calcul de la taille totale
		// [TYPE_SIZE (2)] + [TYPE (N)] + [DATA_SIZE (4)] + [DATA (M)]
		int totalSize = 2 + typeBytes.Length + 4 + Data.Length;
		byte[] buffer = new byte[totalSize];
		int offset = 0;

		// TYPE_SIZE (2 bytes, ushort)
		BitConverter.GetBytes((ushort)typeBytes.Length).CopyTo(buffer, offset);
		offset += 2;

		// TYPE (N bytes)
		typeBytes.CopyTo(buffer, offset);
		offset += typeBytes.Length;

		// DATA_SIZE (4 bytes, int)
		BitConverter.GetBytes(Data.Length).CopyTo(buffer, offset);
		offset += 4;

		// DATA (M bytes)
		Data.CopyTo(buffer, offset);

		return buffer;
	}

	/// <summary>
	/// Désérialise un paquet depuis des bytes
	/// </summary>
	public static Packet Deserialize(byte[] buffer) {
		if (buffer.Length < 6) // Minimum:  2 + 0 + 4 + 0
			throw new ProtocolViolationException("Paquet trop court");

		int offset = 0;

		// TYPE_SIZE
		ushort typeSize = BitConverter.ToUInt16(buffer, offset);
		offset += 2;

		if (buffer.Length < 2 + typeSize + 4)
			throw new ProtocolViolationException("Paquet malformé:  type tronqué");

		// TYPE
		string typeName = Encoding.UTF8.GetString(buffer, offset, typeSize);
		offset += typeSize;

		if (!Enum.TryParse<PacketType>(typeName, out var type))
			throw new ProtocolViolationException($"Type de paquet inconnu: {typeName}");

		// DATA_SIZE
		int dataSize = BitConverter.ToInt32(buffer, offset);
		offset += 4;

		if (buffer.Length < offset + dataSize)
			throw new ProtocolViolationException("Paquet malformé: données tronquées");

		// DATA
		byte[] data = new byte[dataSize];
		Array.Copy(buffer, offset, data, 0, dataSize);

		return new Packet(type, data);
	}

	/// <summary>
	/// Lit le payload comme du texte UTF-8
	/// </summary>
	public string GetDataAsString() => Encoding.UTF8.GetString(Data);

	public override string ToString() => $"Packet({Type}, {Data.Length} bytes)";
}
