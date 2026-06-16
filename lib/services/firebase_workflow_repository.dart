import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/erp_models.dart';
import 'company_drive_storage_service.dart';

class FirebaseWorkflowRepository {
  FirebaseWorkflowRepository({
    FirebaseFirestore? firestore,
    CompanyDriveStorageService? driveStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _driveStorage = driveStorage ?? CompanyDriveStorageService();

  final FirebaseFirestore _firestore;
  final CompanyDriveStorageService _driveStorage;

  bool get isDriveUploadConfigured => _driveStorage.isConfigured;
  bool get isUsingLocalDriveUpload => _driveStorage.isLocalDebugEndpoint;
  Future<String?> checkDriveUploadAvailability() {
    return _driveStorage.checkAvailability();
  }

  Future<LocalDriveBackendBootstrapResult> ensureLocalDriveBackendRunning() {
    return _driveStorage.ensureLocalDebugBackendRunning();
  }

  Future<DriveAuthReconnectResult> reconnectLocalDriveAuthentication() {
    return _driveStorage.reconnectLocalDriveAuthentication();
  }

  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _firestore.collection('workflow_orders');

  CollectionReference<Map<String, dynamic>> get _profilesCollection =>
      _firestore.collection('workspace_profiles');

  CollectionReference<Map<String, dynamic>> get _stockItemsCollection =>
      _firestore.collection('stock_items');

  Stream<List<Map<String, dynamic>>> watchStockItems() {
    return _stockItemsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList(growable: false);
    });
  }

  Future<void> saveStockItem(Map<String, Object?> data) async {
    final id = (data['id'] ?? '').toString();
    await _stockItemsCollection.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteStockItem(String id) async {
    await _stockItemsCollection.doc(id).delete();
  }

  Stream<List<WorkflowOrder>> watchOrders() {
    return _ordersCollection.snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => WorkflowOrder.fromMap(doc.data()))
          .toList(growable: false);
      orders.sort(
        (left, right) => _extractOrderNumber(
          right.code,
        ).compareTo(_extractOrderNumber(left.code)),
      );
      return orders;
    });
  }

  Stream<List<EmployeeWorkspaceProfile>> watchWorkspaceProfiles() {
    return _profilesCollection.snapshots().map((snapshot) {
      final profiles = snapshot.docs
          .map((doc) => EmployeeWorkspaceProfile.fromMap(doc.data()))
          .toList(growable: false);
      profiles.sort((left, right) {
        if (left.isAdministrator != right.isAdministrator) {
          return left.isAdministrator ? -1 : 1;
        }
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
      return profiles;
    });
  }

  Future<void> ensureWorkspaceProfiles(
    List<EmployeeWorkspaceProfile> defaults,
  ) async {
    final snapshot = await _profilesCollection.limit(1).get();
    final batch = _firestore.batch();
    if (snapshot.docs.isEmpty) {
      for (final profile in defaults) {
        batch.set(
          _profilesCollection.doc(_profileDocumentId(profile.email)),
          profile.toMap(),
        );
      }
    } else {
      for (final profile in defaults) {
        batch.set(
          _profilesCollection.doc(_profileDocumentId(profile.email)),
          {
            'login': profile.login,
            'accessCodeHash': profile.accessCodeHash,
            'name': profile.name,
            'cellPhone': profile.cellPhone,
            'role': profile.role,
            'isAdministrator': profile.isAdministrator,
            'accent': profile.accent.toARGB32(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }

  Future<void> updateAllowedStages(
    String email,
    List<WorkflowStage> allowedStages,
  ) async {
    await _profilesCollection.doc(_profileDocumentId(email)).set({
      'allowedStages': allowedStages.map((stage) => stage.name).toList(),
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));
  }

  Future<EmployeeWorkspaceProfile> saveWorkspaceProfile(
    EmployeeWorkspaceProfile profile,
  ) async {
    final resolvedProfile = await _resolveWorkspaceProfilePhoto(profile);
    await _profilesCollection.doc(_profileDocumentId(profile.email)).set({
      ...resolvedProfile.toMap(),
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));
    return resolvedProfile;
  }

  Future<void> deleteWorkspaceProfile(String email) async {
    await _profilesCollection.doc(_profileDocumentId(email)).delete();
  }

  Future<EmployeeWorkspaceProfile> _resolveWorkspaceProfilePhoto(
    EmployeeWorkspaceProfile profile,
  ) async {
    final normalizedName = profile.photoFileName.trim();
    final normalizedLocation = profile.photoFilePath?.trim();

    if (normalizedName.isEmpty ||
        normalizedLocation == null ||
        normalizedLocation.isEmpty) {
      return profile;
    }

    if (_isRemoteLocation(normalizedLocation)) {
      return profile;
    }

    final file = File(normalizedLocation);
    if (!await file.exists()) {
      throw StateError(
        'A foto "$normalizedName" não foi encontrada no caminho salvo.',
      );
    }

    if (!_driveStorage.isConfigured) {
      return profile;
    }

    final extension = _extensionFromName(normalizedName);
    final uploadedFile = await _driveStorage.uploadFile(
      orderCode: 'USUARIOS',
      slot: 'profile_photo',
      localFile: file,
      originalFileName:
          '${profile.login}${extension.isEmpty ? '' : '.$extension'}',
      contentType: _contentTypeForExtension(extension),
    );

    return profile.copyWith(
      photoFileName: uploadedFile.fileName,
      photoFilePath: uploadedFile.downloadUrl ?? uploadedFile.viewUrl,
    );
  }

  Future<WorkflowOrder> saveOrder(WorkflowOrder order) async {
    final resolvedOrder = await _resolveOrderAttachments(order);
    final document = _ordersCollection.doc(resolvedOrder.code);
    final existing = await document.get();
    final now = DateTime.now();
    final payload = <String, dynamic>{
      ...resolvedOrder.toMap(),
      'orderNumber': _extractOrderNumber(resolvedOrder.code),
      'createdAt': existing.data()?['createdAt'] ?? now,
      'updatedAt': now,
    };

    await document.set(payload, SetOptions(merge: true));
    return resolvedOrder;
  }

  Future<void> deleteOrder(String orderCode) async {
    await _ordersCollection.doc(orderCode).delete();
  }

  Future<WorkflowOrder> _resolveOrderAttachments(WorkflowOrder order) async {
    final proposal = await _resolveAttachment(
      orderCode: order.code,
      slot: 'proposal',
      fileName: order.proposalFileName,
      fileLocation: order.proposalFilePath,
    );
    final details = await _resolveAttachment(
      orderCode: order.code,
      slot: 'details',
      fileName: order.detailFileName,
      fileLocation: order.detailFilePath,
    );
    final materials = await _resolveAttachment(
      orderCode: order.code,
      slot: 'materials',
      fileName: order.materialFileName,
      fileLocation: order.materialFilePath,
    );
    final consolidatedProposal = await _resolveAttachment(
      orderCode: order.code,
      slot: 'consolidated_proposal',
      fileName: order.consolidatedProposalFileName,
      fileLocation: order.consolidatedProposalFilePath,
    );
    final contract = await _resolveAttachment(
      orderCode: order.code,
      slot: 'contract',
      fileName: order.contractFileName,
      fileLocation: order.contractFilePath,
    );
    final electricalProject = await _resolveAttachment(
      orderCode: order.code,
      slot: 'electrical_project',
      fileName: order.electricalProjectFileName,
      fileLocation: order.electricalProjectFilePath,
    );
    final panelLayout = await _resolveAttachment(
      orderCode: order.code,
      slot: 'panel_layout',
      fileName: order.panelLayoutFileName,
      fileLocation: order.panelLayoutFilePath,
    );
    final pushButtonTable = await _resolveAttachment(
      orderCode: order.code,
      slot: 'push_button_table',
      fileName: order.pushButtonTableFileName,
      fileLocation: order.pushButtonTableFilePath,
    );
    final engineeringData = await _resolveAttachment(
      orderCode: order.code,
      slot: 'engineering_data',
      fileName: order.engineeringDataFileName,
      fileLocation: order.engineeringDataFilePath,
    );
    final serviceOrder = await _resolveAttachment(
      orderCode: order.code,
      slot: 'service_order',
      fileName: order.serviceOrderFileName,
      fileLocation: order.serviceOrderFilePath,
    );

    return order.copyWith(
      proposalFileName: proposal.fileName,
      proposalFilePath: proposal.fileLocation,
      detailFileName: details.fileName,
      detailFilePath: details.fileLocation,
      materialFileName: materials.fileName,
      materialFilePath: materials.fileLocation,
      consolidatedProposalFileName: consolidatedProposal.fileName,
      consolidatedProposalFilePath: consolidatedProposal.fileLocation,
      contractFileName: contract.fileName,
      contractFilePath: contract.fileLocation,
      electricalProjectFileName: electricalProject.fileName,
      electricalProjectFilePath: electricalProject.fileLocation,
      panelLayoutFileName: panelLayout.fileName,
      panelLayoutFilePath: panelLayout.fileLocation,
      pushButtonTableFileName: pushButtonTable.fileName,
      pushButtonTableFilePath: pushButtonTable.fileLocation,
      engineeringDataFileName: engineeringData.fileName,
      engineeringDataFilePath: engineeringData.fileLocation,
      serviceOrderFileName: serviceOrder.fileName,
      serviceOrderFilePath: serviceOrder.fileLocation,
    );
  }

  Future<_StoredAttachment> _resolveAttachment({
    required String orderCode,
    required String slot,
    required String fileName,
    required String? fileLocation,
  }) async {
    final normalizedName = fileName.trim();
    final normalizedLocation = fileLocation?.trim();

    if (normalizedName.isEmpty) {
      return const _StoredAttachment(fileName: '', fileLocation: null);
    }

    if (normalizedLocation == null || normalizedLocation.isEmpty) {
      return _StoredAttachment(
        fileName: normalizedName,
        fileLocation: normalizedLocation,
      );
    }

    if (_isRemoteLocation(normalizedLocation)) {
      return _StoredAttachment(
        fileName: normalizedName,
        fileLocation: normalizedLocation,
      );
    }

    final file = File(normalizedLocation);
    if (!await file.exists()) {
      throw StateError(
        'O arquivo "$normalizedName" não foi encontrado no caminho salvo para upload.',
      );
    }

    if (!_driveStorage.isConfigured) {
      return _StoredAttachment(
        fileName: normalizedName,
        fileLocation: normalizedLocation,
      );
    }

    final extension = _extensionFromName(normalizedName);
    final uploadedFile = await _driveStorage.uploadFile(
      orderCode: orderCode,
      slot: slot,
      localFile: file,
      originalFileName: normalizedName,
      contentType: _contentTypeForExtension(extension),
    );

    return _StoredAttachment(
      fileName: uploadedFile.fileName,
      fileLocation: uploadedFile.viewUrl,
    );
  }

  String _profileDocumentId(String email) {
    return email.trim().toLowerCase();
  }

  int _extractOrderNumber(String code) {
    return int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  bool _isRemoteLocation(String location) {
    final uri = Uri.tryParse(location);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _extensionFromName(String value) {
    final dotIndex = value.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == value.length - 1) {
      return '';
    }
    return value.substring(dotIndex + 1).toLowerCase();
  }

  String? _contentTypeForExtension(String extension) {
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'csv' => 'text/csv',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'zip' => 'application/zip',
      _ => null,
    };
  }

  void dispose() {
    _driveStorage.dispose();
  }
}

class _StoredAttachment {
  const _StoredAttachment({required this.fileName, required this.fileLocation});

  final String fileName;
  final String? fileLocation;
}
