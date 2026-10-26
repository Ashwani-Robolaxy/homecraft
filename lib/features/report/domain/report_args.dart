/// Arguments passed to the TakeActionScreen / report flow.
class ReportArgs {
  const ReportArgs({
    required this.professionalId,
    this.professionalName = 'Professional',
    this.isCurrentUserProfessional = false,
  });

  final String professionalId;
  final String professionalName;
  final bool isCurrentUserProfessional;
}
