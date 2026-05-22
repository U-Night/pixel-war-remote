using Godot;
using System;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public partial class TestClient : Node
{
	
	[Export] public string ServerIp = "127.0.0.1";
	[Export] public int ServerPort = 6967; 

	private TcpClient _tcpClient;
	private TcpMessageFramer _framer;
	private CancellationTokenSource _cts;

	public override void _Ready()
	{
		// On lance la connexion de manière asynchrone pour ne pas bloquer Godot
		_ = StartClientAsync();
	}

	private async Task StartClientAsync()
	{
		try
		{
			GD.Print($"[TestClient] Tentative de connexion à {ServerIp}:{ServerPort}...");
			_tcpClient = new TcpClient();
			await _tcpClient.ConnectAsync(ServerIp, ServerPort);
			
			// On utilise le framer de tes collègues pour respecter le format [Longueur][Payload]
			_framer = new TcpMessageFramer(_tcpClient.GetStream());
			_cts = new CancellationTokenSource();

			// Lancement du processus de Handshake
			bool handshakeOk = await PerformHandshakeAsync();
			
			if (handshakeOk)
			{
				// Démarrer la boucle d'écoute des messages en tâche de fond
				_ = ReceiveLoopAsync(_cts.Token);

				// On envoie un paquet de test pour voir si le serveur le reçoit bien
				await SendPacketAsync(new Packet(PacketType.Message, "Bonjour depuis la télécommande test !"));
			}
			else
			{
				GD.PrintErr("[TestClient] Échec du handshake. Connexion avortée.");
				Disconnect();
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[TestClient] Erreur de connexion: {ex.Message}");
		}
	}

	private async Task<bool> PerformHandshakeAsync()
	{
		// 1. Le serveur est censé nous envoyer "PIXELWAR 1.0"
		string serverHello = await _framer.ReceiveAsync(_cts.Token);
		if (serverHello != "PIXELWAR 1.0")
		{
			GD.PrintErr($"[TestClient] Protocole invalide. Reçu du serveur : {serverHello}");
			return false;
		}

		// 2. On répond "REMOTE 1.0" comme attendu par le GameClient.cs
		await _framer.SendAsync("REMOTE 1.0", _cts.Token);

		// 3. Le serveur doit nous valider avec "WELCOME {id}"
		string welcomeMsg = await _framer.ReceiveAsync(_cts.Token);
		if (welcomeMsg != null && welcomeMsg.StartsWith("WELCOME"))
		{
			GD.Print($"[TestClient] Connexion établie avec succès ! Message serveur : {welcomeMsg}");
			return true;
		}

		return false;
	}

	private async Task ReceiveLoopAsync(CancellationToken ct)
	{
		try
		{
			while (!ct.IsCancellationRequested && _tcpClient.Connected)
			{
				// Le Framer attend les prochains messages sous forme de string
				string message = await _framer.ReceiveAsync(ct);
				if (message == null) 
				{
					GD.Print("[TestClient] Le serveur a fermé la connexion.");
					break;
				}

				// On ignore les messages du protocole de connexion (handshake)
				if (message.StartsWith("PIXELWAR") || message.StartsWith("WELCOME")) 
				{
					continue;
				}

				try
				{
					// EXACTEMENT COMME LE SERVEUR : On convertit la chaîne en UTF-8
					byte[] packetBytes = Encoding.UTF8.GetBytes(message);
					
					// On reconstitue le Packet
					Packet packet = Packet.Deserialize(packetBytes);
					HandlePacket(packet);
				}
				catch (Exception ex)
				{
					GD.PrintErr($"[TestClient] Erreur de lecture du paquet : {ex.Message}");
				}
			}
		}
		catch (Exception ex)
		{
			if (!ct.IsCancellationRequested)
			{
				GD.PrintErr($"[TestClient] Erreur dans la boucle de réception : {ex.Message}");
			}
		}
		finally
		{
			Disconnect();
		}
	}

	public async Task SendPacketAsync(Packet packet)
	{
		if (_tcpClient == null || !_tcpClient.Connected) return;

		try
		{
			// 1. On sérialise le paquet en binaire (byte[])
			byte[] serializedBytes = packet.Serialize();
			
			// 2. EXACTEMENT COMME LE SERVEUR : On convertit les octets en string via UTF-8
			string message = Encoding.UTF8.GetString(serializedBytes);
			
			// 3. On envoie la chaîne
			await _framer.SendAsync(message);
			GD.Print($"[TestClient] Paquet de type {packet.Type} envoyé au serveur.");
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[TestClient] Erreur lors de l'envoi du paquet : {ex.Message}");
		}
	}

	private void HandlePacket(Packet packet)
	{
		// Traitement classique des paquets
		GD.Print($"[TestClient] Paquet reçu du serveur. Type : {packet.Type}");
		
		if (packet.Type == PacketType.Message)
		{
			GD.Print($"[TestClient] Contenu du message : {packet.GetDataAsString()}");
		}
	}

	private void Disconnect()
	{
		_cts?.Cancel();
		_tcpClient?.Close();
		GD.Print("[TestClient] Client déconnecté et processus arrêté.");
	}

	public override void _ExitTree()
	{
		// Lorsque la scène Godot se ferme, on coupe proprement la connexion réseau
		Disconnect();
	}
}