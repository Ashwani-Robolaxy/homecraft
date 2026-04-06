class ProfessionalChatArgs {
  const ProfessionalChatArgs({
    required this.clientUserId,
    this.clientDisplayName,
    this.projectId,
    this.isCurrentUserProfessional = true,
    this.professionalId,
  });

  /// The OTHER person's user-ID.
  ///  - When [isCurrentUserProfessional] is true  → this is the client's userId.
  ///  - When [isCurrentUserProfessional] is false → this is the professional's userId.
  final String clientUserId;
  final String? clientDisplayName;
  final String? projectId;

  /// `true`  → logged-in user is a Professional (uses /professionals/chat/… endpoints).
  /// `false` → logged-in user is a Client       (uses /users/chat/… endpoints).
  final bool isCurrentUserProfessional;

  /// The professional's userId — used to fetch their portfolio in the Media screen.
  /// When [isCurrentUserProfessional] is false, this is the same as [clientUserId].
  final String? professionalId;

  /// Resolves the professional's ID for portfolio fetching.
  String? get resolvedProfessionalId =>
      professionalId ?? (!isCurrentUserProfessional ? clientUserId : null);
}
