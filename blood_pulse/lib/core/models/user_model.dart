class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String bloodGroup;
  final String district;
  final String upazila;
  final String nidNumber;
  final bool isAvailable;
  final String role; // 'donor' or 'admin'

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.bloodGroup,
    required this.district,
    required this.upazila,
    required this.nidNumber,
    this.isAvailable = true,
    this.role = 'donor',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      bloodGroup: json['bloodGroup'] as String,
      district: json['district'] as String,
      upazila: json['upazila'] as String,
      nidNumber: json['nidNumber'] as String,
      isAvailable: json['isAvailable'] as bool? ?? true,
      role: json['role'] as String? ?? 'donor',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'district': district,
      'upazila': upazila,
      'nidNumber': nidNumber,
      'isAvailable': isAvailable,
      'role': role,
    };
  }
}
