import 'trip_member.dart';

class JoinResult {
  final bool alreadyMember;
  final TripMember? member;

  const JoinResult({required this.alreadyMember, this.member});

  factory JoinResult.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>?;
    return JoinResult(
      alreadyMember: json['alreadyMember'] == true,
      member: member == null ? null : TripMember.fromJson(member),
    );
  }
}
