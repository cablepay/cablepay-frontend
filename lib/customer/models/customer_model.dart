class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String? district;
  final String? pincode;
  final String? address;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.district,
    this.pincode,
    this.address,
  });

  Map<String, dynamic> toMap() => {
    '_id': id,
    'name': name,
    'phone': phone,
    'district': district,
    'pincode': pincode,
    'address': address,
  };

  static CustomerModel fromMap(Map<String, dynamic> m) => CustomerModel(
    id: m['_id'] ?? m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    district: m['district'],
    pincode: m['pincode'],
    address: m['address'],
  );
}
