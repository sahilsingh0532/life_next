import 'package:hive/hive.dart';

part 'memo_model.g.dart';

@HiveType(typeId: 0)
class Memo extends HiveObject {
  @HiveField(0)
  String text;

  @HiveField(1)
  String? imagePath;

  Memo({required this.text, this.imagePath});
}
