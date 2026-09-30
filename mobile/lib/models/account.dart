class Account {
  final int id;
  final int userId;
  final String serviceName;
  final String? serviceUrl;
  final String? emailUsed;
  final String? usernameUsed;
  final String category;
  final bool has2fa;
  final String? passwordGroup;
  final String? loginMethod;
  final String? recoveryEmail;
  final String? recoveryPhone;
  final List<String> permissions;
  final double riskScore;
  final int breachCount;
  final String? lastBreachDate;
  final bool isActive;
  final String? notes;

  Account({
    required this.id,
    required this.userId,
    required this.serviceName,
    this.serviceUrl,
    this.emailUsed,
    this.usernameUsed,
    this.category = 'other',
    this.has2fa = false,
    this.passwordGroup,
    this.loginMethod,
    this.recoveryEmail,
    this.recoveryPhone,
    this.permissions = const [],
    this.riskScore = 0,
    this.breachCount = 0,
    this.lastBreachDate,
    this.isActive = true,
    this.notes,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      serviceName: json['service_name'] ?? '',
      serviceUrl: json['service_url'],
      emailUsed: json['email_used'],
      usernameUsed: json['username_used'],
      category: json['category'] ?? 'other',
      has2fa: json['has_2fa'] ?? false,
      passwordGroup: json['password_group'],
      loginMethod: json['login_method'],
      recoveryEmail: json['recovery_email'],
      recoveryPhone: json['recovery_phone'],
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
      riskScore: (json['risk_score'] ?? 0).toDouble(),
      breachCount: json['breach_count'] ?? 0,
      lastBreachDate: json['last_breach_date'],
      isActive: json['is_active'] ?? true,
      notes: json['notes'],
    );
  }

  String get riskLevel {
    if (riskScore >= 75) return 'Critical';
    if (riskScore >= 50) return 'High';
    if (riskScore >= 25) return 'Medium';
    return 'Low';
  }
}

class AccountConnection {
  final int id;
  final int fromAccountId;
  final int toAccountId;
  final String connectionType;
  final String? fromServiceName;
  final String? toServiceName;

  AccountConnection({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.connectionType,
    this.fromServiceName,
    this.toServiceName,
  });

  factory AccountConnection.fromJson(Map<String, dynamic> json) {
    return AccountConnection(
      id: json['id'] ?? 0,
      fromAccountId: json['from_account_id'] ?? 0,
      toAccountId: json['to_account_id'] ?? 0,
      connectionType: json['connection_type'] ?? '',
      fromServiceName: json['from_service_name'],
      toServiceName: json['to_service_name'],
    );
  }
}

class FixAction {
  final int id;
  final int? accountId;
  final String actionType;
  final String description;
  final int priority;
  final double riskReduction;
  final String status;
  final String? serviceName;

  FixAction({
    required this.id,
    this.accountId,
    required this.actionType,
    required this.description,
    this.priority = 3,
    this.riskReduction = 0,
    this.status = 'pending',
    this.serviceName,
  });

  factory FixAction.fromJson(Map<String, dynamic> json) {
    return FixAction(
      id: json['id'] ?? 0,
      accountId: json['account_id'],
      actionType: json['action_type'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 3,
      riskReduction: (json['risk_reduction'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      serviceName: json['service_name'],
    );
  }
}
