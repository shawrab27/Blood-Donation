// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/services/institution_service.dart';

void main() {
  group('B3: InstitutionService and CSV Parser', () {
    test('parseCsv correctly extracts schools, colleges, madrasas, and universities', () {
      const csvData = '''id,eiin,name,institution_type,district_name,upazila_name
1,100108,CHAWRA NESARIA SENIOR ALIM MADRASAH,madrasa,Barguna,Amtali
2,131945,NOTRE DAME COLLEGE,college,Dhaka,Motijheel
3,108154,DHAKA COLLEGIATE SCHOOL,school,Dhaka,Kotwali
4,64221,Ahsanullah University of Science and Technology,university,Dhaka,Tejgaon
5,,Dhaka Polytechnic Institute,technical,Dhaka,Tejgaon
''';

      final service = InstitutionService.instance;
      final parsed = service.parseCsv(csvData);

      expect(parsed.length, 5);

      final types = parsed.map((e) => e['institution_type']).toSet();
      expect(types, containsAll(['madrasa', 'college', 'school', 'university', 'technical']));

      final madrasa = parsed.firstWhere((e) => e['name'] == 'CHAWRA NESARIA SENIOR ALIM MADRASAH');
      expect(madrasa['institution_type'], 'madrasa');
      expect(madrasa['district_name'], 'Barguna');

      final college = parsed.firstWhere((e) => e['name'] == 'NOTRE DAME COLLEGE');
      expect(college['institution_type'], 'college');

      final school = parsed.firstWhere((e) => e['name'] == 'DHAKA COLLEGIATE SCHOOL');
      expect(school['institution_type'], 'school');
    });

    test('parseCsv handles quotes and commas in institution names safely', () {
      const csvData = '''id,eiin,name,institution_type,district_name,upazila_name
1,123456,"St. Joseph Higher Secondary School, Dhaka",school,Dhaka,Mohammadpur
2,789101,"Ideal School and College, Motijheel",college,Dhaka,Motijheel
''';

      final service = InstitutionService.instance;
      final parsed = service.parseCsv(csvData);

      expect(parsed.length, 2);
      expect(parsed[0]['name'], 'St. Joseph Higher Secondary School, Dhaka');
      expect(parsed[1]['name'], 'Ideal School and College, Motijheel');
    });
  });
}
