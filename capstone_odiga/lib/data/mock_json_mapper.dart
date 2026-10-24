// Compatibility for callers of the previous mapper. New code uses lib/api/.
export '../api/api_mappers.dart' show ApiMappers;
import '../api/api_mappers.dart';

typedef MockJsonMapper = ApiMappers;
