// GENERATED CODE - stub adapter. Run build_runner to generate the real adapter.
import 'package:hive/hive.dart';
import 'job_offer.dart';

class JobOfferAdapter extends TypeAdapter<JobOffer> {
  @override
  final int typeId = 0;

  @override
  JobOffer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JobOffer(
      id: fields[0] as int,
      title: fields[1] as String,
      company: fields[2] as String,
      description: fields[3] as String,
      address: fields[4] as String,
      location: fields[5] as String,
      city: fields[6] as String,
      region: fields[7] as String,
      isRemote: fields[8] as bool,
      latitude: fields[9] as double?,
      longitude: fields[10] as double?,
      salaryMin: fields[11] as int?,
      salaryMax: fields[12] as int?,
      postedAt: fields[13] as DateTime?,
      fetchedAt: fields[14] as DateTime?,
      contractTypes: (fields[15] as List).cast<String>(),
      workTime: fields[16] as String,
      requirements: (fields[17] as List).cast<String>(),
      duties: (fields[18] as List).cast<String>(),
      benefits: (fields[19] as List).cast<String>(),
      companyLogoUrl: fields[20] as String?,
      companyWebsite: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, JobOffer obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.company)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.city)
      ..writeByte(7)
      ..write(obj.region)
      ..writeByte(8)
      ..write(obj.isRemote)
      ..writeByte(9)
      ..write(obj.latitude)
      ..writeByte(10)
      ..write(obj.longitude)
      ..writeByte(11)
      ..write(obj.salaryMin)
      ..writeByte(12)
      ..write(obj.salaryMax)
      ..writeByte(13)
      ..write(obj.postedAt)
      ..writeByte(14)
      ..write(obj.fetchedAt)
      ..writeByte(15)
      ..write(obj.contractTypes)
      ..writeByte(16)
      ..write(obj.workTime)
      ..writeByte(17)
      ..write(obj.requirements)
      ..writeByte(18)
      ..write(obj.duties)
      ..writeByte(19)
      ..write(obj.benefits)
      ..writeByte(20)
      ..write(obj.companyLogoUrl)
      ..writeByte(21)
      ..write(obj.companyWebsite);
  }
}
