class TokenResponse {
  final String token;
  final String roomName;
  final String participantName;
  final String livekitUrl;

  TokenResponse({
    required this.token,
    required this.roomName,
    required this.participantName,
    required this.livekitUrl,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      token: json['token'] as String,
      roomName: json['roomName'] as String,
      participantName: json['participantName'] as String,
      livekitUrl: json['livekitUrl'] as String,
    );
  }
}
