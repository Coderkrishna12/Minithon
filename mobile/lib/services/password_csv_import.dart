class CsvImportService {
  final String serviceName;
  final String? passwordGroup;
  final String? url;
  final String? username;
  const CsvImportService(this.serviceName, this.passwordGroup, {this.url, this.username});

  /// Only the site, login name and a locally generated reuse label leave the phone. Never the password.
  Map<String, dynamic> toApiJson() => {
        'service_name': serviceName,
        if (passwordGroup != null) 'password_group': passwordGroup,
        if (url != null && url!.isNotEmpty) 'url': url,
        if (username != null && username!.isNotEmpty) 'username': username,
      };
}

/// Parse common password-manager CSV exports on-device. Password strings exist
/// only in this call's local maps; the returned objects contain no credentials.
List<CsvImportService> parsePasswordManagerCsv(String contents) {
  final rows = _parseCsvRows(contents).where((row) => row.any((cell) => cell.isNotEmpty)).toList();
  if (rows.length < 2) return const [];
  final headers = rows.first.map((v) => v.trim().toLowerCase()).toList();
  int find(Set<String> names) => headers.indexWhere(names.contains);
  // Header names used by Google/Chrome, Bitwarden, 1Password, LastPass, Dashlane and Firefox exports.
  var serviceColumn = find({'name', 'service', 'service name', 'title', 'website', 'url', 'login_uri', 'login'});
  var passwordColumn = find({'password', 'passphrase', 'login_password'});
  final urlColumn = find({'url', 'website', 'login_uri', 'uri', 'origin_url'});
  final userColumn = find({'username', 'login_username', 'user', 'email', 'login name'});
  final hasHeader = serviceColumn >= 0 && passwordColumn >= 0;
  if (!hasHeader) {
    serviceColumn = 0;
    passwordColumn = 1;
  }
  final dataRows = hasHeader ? rows.skip(1) : rows;
  final entries = <({String service, String password, String? url, String? user})>[];
  String? cell(List<String> row, int column) => column >= 0 && column < row.length ? row[column].trim() : null;
  for (final row in dataRows) {
    if (serviceColumn >= row.length || passwordColumn >= row.length) continue;
    final service = row[serviceColumn].trim();
    final password = row[passwordColumn];
    if (service.isNotEmpty && password.isNotEmpty) {
      entries.add((
        service: service,
        password: password,
        url: hasHeader ? cell(row, urlColumn) : null,
        user: hasHeader ? cell(row, userColumn) : null,
      ));
    }
  }

  final passwordCounts = <String, int>{};
  for (final entry in entries) {
    passwordCounts.update(entry.password, (n) => n + 1, ifAbsent: () => 1);
  }
  final groupByPassword = <String, String>{};
  var groupNumber = 0;
  for (final entry in entries) {
    if (passwordCounts[entry.password]! > 1 && !groupByPassword.containsKey(entry.password)) {
      groupByPassword[entry.password] = 'reuse_${++groupNumber}';
    }
  }
  final seen = <String>{};
  return entries
      .where((entry) => seen.add(entry.service.toLowerCase()))
      .map((entry) => CsvImportService(
            entry.service,
            groupByPassword[entry.password],
            url: entry.url,
            username: entry.user,
          ))
      .toList();
}

List<List<String>> _parseCsvRows(String input) {
  final rows = <List<String>>[];
  final values = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      values.add(cell.toString());
      cell.clear();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      values.add(cell.toString());
      cell.clear();
      rows.add(values.toList());
      values.clear();
    } else {
      cell.write(char);
    }
  }
  values.add(cell.toString());
  if (values.any((value) => value.isNotEmpty)) rows.add(values);
  return rows;
}
