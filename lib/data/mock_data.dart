import 'package:flutter/material.dart';

import '../auth/workspace_credentials.dart';
import '../models/erp_models.dart';

const workflowStages = WorkflowStage.values;

const List<ClientProfile> clients = [];

final List<WorkflowOrder> mockOrders = [];

final List<EmployeeWorkspaceProfile> workspaceProfiles = [
  EmployeeWorkspaceProfile(
    email: 'admin@danf.com',
    login: 'admin',
    name: 'Administrador ERP',
    cellPhone: '',
    role: 'Administração do sistema',
    isAdministrator: true,
    allowedStages: [
      WorkflowStage.customerRegistration,
      WorkflowStage.estimating,
      WorkflowStage.finance,
      WorkflowStage.relationship,
      WorkflowStage.engineering,
      WorkflowStage.assembly,
      WorkflowStage.installation,
    ],
    accent: Color(0xFF12372A),
    accessCodeHash: hashWorkspaceAccessCode('1234'),
  ),
];

const List<WorkspaceTask> workspaceTasks = [];
