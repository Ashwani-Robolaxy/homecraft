/// Arguments passed to the TakeActionScreen / report flow.
class ReportArgs {
  const ReportArgs({
    required this.professionalId,
    this.professionalName = 'Professional',
  });

  final String professionalId;
  final String professionalName;
}
