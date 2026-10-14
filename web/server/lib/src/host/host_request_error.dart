/// An additive error code lets clients translate failures without parsing logs.
class HostRequestError extends FormatException {
  const HostRequestError(this.code, String message) : super(message);

  final String code;
}
