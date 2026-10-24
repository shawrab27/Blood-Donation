import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/services/institution_service.dart';

void main() {
  group('InstitutionService CSV Parser', () {
    test('parses CSV rows of each institution type (University, College, School, Madrasa)', () {
      const sampleCsv = '''id,eiin,name,institution_type,district_name,upazila_name
1,134151,Dhaka University,university,Dhaka,Ramna
2,108215,Dhaka College,college,Dhaka,New Market
3,107841,Motijheel Government Boys High School,school,Dhaka,Motijheel
4,108192,Tamirul Millat Kamil Madrasah,madrasa,Dhaka,Jatrabari
''';

      final institutions = InstitutionService.instance.parseCsv(sampleCsv);

      expect(institutions.length, equals(4));

      // 1. University
      final uni = institutions.firstWhere((i) => i['institution_type'] == 'university');
      expect(uni['name'], equals('Dhaka University'));
      expect(uni['district_name'], equals('Dhaka'));
      expect(uni['upazila_name'], equals('Ramna'));

      // 2. College
      final col = institutions.firstWhere((i) => i['institution_type'] == 'college');
      expect(col['name'], equals('Dhaka College'));
      expect(col['district_name'], equals('Dhaka'));
      expect(col['upazila_name'], equals('New Market'));

      // 3. School
      final sch = institutions.firstWhere((i) => i['institution_type'] == 'school');
      expect(sch['name'], equals('Motijheel Government Boys High School'));
      expect(sch['district_name'], equals('Dhaka'));
      expect(sch['upazila_name'], equals('Motijheel'));

      // 4. Madrasa
      final mad = institutions.firstWhere((i) => i['institution_type'] == 'madrasa');
      expect(mad['name'], equals('Tamirul Millat Kamil Madrasah'));
      expect(mad['district_name'], equals('Dhaka'));
      expect(mad['upazila_name'], equals('Jatrabari'));
    });
  });
}
