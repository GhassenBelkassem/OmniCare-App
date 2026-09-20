class UserDto {
  final String? email;
  final String? name;
  final String? phoneNumber;

  const UserDto({this.email, this.name, this.phoneNumber});

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      email: json['email']?.toString(),
      name: json['name']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
    );
  }
}
