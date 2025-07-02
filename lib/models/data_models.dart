// ParentSub model for User.parents
class ParentSub {
  final String name;
  final String email;

  ParentSub({
    required this.name,
    required this.email,
  });

  factory ParentSub.fromJson(Map<String, dynamic> json) {
    return ParentSub(
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
  };
}

// Data model for User
class User {
  final String id;
  final String email;
  final String password;
  final UserRole role;
  final String name;
  final String? gender;
  final int? batch;
  final List<ParentSub>? parents;

  User({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
    required this.name,
    this.batch,
    this.gender,
    this.parents,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'role': role.toString(),
      'name': name,
      'batch': batch,
      'gender': gender,
      'parents': parents?.map((p) => p.toJson()).toList(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'],
      password: json['password'] ?? '',
      role: UserRole.values.firstWhere((e) => e.toString() == json['role'] || e.name == json['role']),
      name: json['name'],
      batch: json['batch'],
      gender: json['gender'],
      parents: (json['parents'] as List?)?.map((p) => ParentSub.fromJson(p)).toList(),
    );
  }
}

// Enum for User Roles
enum UserRole {
  student,
  parent,
  warden,
  guard,
  admin,
}

// Data model for Leave Request
class LeaveRequest {
  final String id;
  final String studentId;
  final String studentName; // <-- Add this line
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String? attachmentPath;
  final DateTime? returnDateTime;
  final LeaveStatusDetail parentStatus;
  final LeaveStatusDetail wardenStatus;
  final LeaveStatusDetail guardStatus;
  final LeaveStatusDetail adminStatus;
  final DateTime createdAt;
  final String? qrCode;
  final String? parentToken;

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName, // <-- Add this line
    required this.reason,
    required this.startDate,
    required this.endDate,
    this.attachmentPath,
    this.returnDateTime,
    required this.parentStatus,
    required this.wardenStatus,
    required this.guardStatus,
    required this.adminStatus,
    required this.createdAt,
    this.qrCode,
    this.parentToken,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['_id'] ?? '',
      studentId: json['student']?['_id'] ?? json['student'] ?? '',
      studentName: json['student']?['name'] ?? '', // <-- Add this line
      reason: json['reason'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      attachmentPath: json['documentUrl'],
      returnDateTime: json['returnDateTime'] != null
          ? DateTime.tryParse(json['returnDateTime'])
          : null,
      parentStatus: LeaveStatusDetail.fromJson(json['parentStatus']),
      wardenStatus: LeaveStatusDetail.fromJson(json['wardenStatus']),
      guardStatus: LeaveStatusDetail.fromJson(json['guardStatus']),
      adminStatus: LeaveStatusDetail.fromJson(json['adminStatus']),
      createdAt: DateTime.parse(json['createdAt']),
      qrCode: json['qrCode'],
      parentToken: json['parentToken'],
    );
  }

  
}

// Add a class to represent status details for each role
class LeaveStatusDetail {
  final String status;
  final DateTime? decidedAt;
  final String? reason;

  LeaveStatusDetail({
    required this.status,
    this.decidedAt,
    this.reason,
  });

  factory LeaveStatusDetail.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LeaveStatusDetail(status: 'pending');
    }
    return LeaveStatusDetail(
      status: json['status'] ?? 'pending',
      decidedAt: json['decidedAt'] != null ? DateTime.tryParse(json['decidedAt']) : null,
      reason: json['reason'],
    );
  }
}

// Enum for Leave Status
enum LeaveStatus {
  pendingParentApproval,
  parentApproved,
  parentRejected,
  wardenApproved,
  wardenRejected,
  guardApproved,
  guardRejected,
  adminPending,
  adminStopped,
}

// Helper to map backend status string to enum
LeaveStatus parseLeaveStatus(String status, {String role = 'parent'}) {
  switch (role) {
    case 'parent':
      if (status == 'pending') return LeaveStatus.pendingParentApproval;
      if (status == 'approved') return LeaveStatus.parentApproved;
      if (status == 'rejected') return LeaveStatus.parentRejected;
      break;
    case 'warden':
      if (status == 'approved') return LeaveStatus.wardenApproved;
      if (status == 'rejected') return LeaveStatus.wardenRejected;
      break;
    case 'guard':
      if (status == 'approved') return LeaveStatus.guardApproved;
      if (status == 'rejected') return LeaveStatus.guardRejected;
      break;
    case 'admin':
      if (status == 'pending') return LeaveStatus.adminPending;
      if (status == 'stopped') return LeaveStatus.adminStopped;
      break;
  }
  return LeaveStatus.pendingParentApproval;
}

// Data model for Notification
class AppNotification {
  final String id;
  final String? recipient;
  final String? type;
  final String? message;
  final dynamic leave; // Can be String or Map depending on population
  final bool? read;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppNotification({
    required this.id,
    this.recipient,
    this.type,
    this.message,
    this.leave,
    this.read,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'recipient': recipient,
      'type': type,
      'message': message,
      'leave': leave,
      'read': read,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      recipient: json['recipient'],
      type: json['type'],
      message: json['message'],
      leave: json['leave'],
      read: json['read'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}

// Concern model
class Concern {
  final String id;
  final String guardId;
  final String studentName;
  final String batch;
  final String description;
  final String? documentUrl;
  final DateTime createdAt;

  Concern({
    required this.id,
    required this.guardId,
    required this.studentName,
    required this.batch,
    required this.description,
    this.documentUrl,
    required this.createdAt,
  });

  factory Concern.fromJson(Map<String, dynamic> json) {
    return Concern(
      id: json['_id'] ?? '',
      guardId: json['guard']?['_id'] ?? json['guard'] ?? '',
      studentName: json['studentName'],
      batch: json['batch'],
      description: json['description'],
      documentUrl: json['documentUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'guard': guardId,
    'studentName': studentName,
    'batch': batch,
    'description': description,
    'documentUrl': documentUrl,
    'createdAt': createdAt.toIso8601String(),
  };
}

