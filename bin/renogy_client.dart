import 'package:logging/logging.dart';
import 'package:renogy_client/args.dart';

void main(List<String> arguments) {
  var args = Args.parse(arguments);
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  if (args.verbose) Logger.root.level = Level.ALL;
  Logger.root.fine(args);

  print(args);
}
