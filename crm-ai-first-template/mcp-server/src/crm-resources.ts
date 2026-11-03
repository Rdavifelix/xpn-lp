export const crmResources = {
  "contato": {
    "table": "leads",
    "plural": "contatos",
    "search": "name",
    "fields": [
      "name",
      "email",
      "phone",
      "phone2",
      "instagram",
      "company_name",
      "job_title",
      "source",
      "context",
      "city_name",
      "state",
      "country",
      "tags",
      "status",
      "sales_rep_id",
      "expected_revenue",
      "bant_budget",
      "bant_authority",
      "bant_need",
      "bant_timeline",
      "qualification",
      "monthly_revenue",
      "lead_temperature",
      "email_opted_out"
    ],
    "required": [
      "name"
    ],
    "read": [
      "id",
      "name",
      "email",
      "phone",
      "phone2",
      "instagram",
      "company_name",
      "job_title",
      "source",
      "context",
      "city_name",
      "state",
      "country",
      "tags",
      "status",
      "sales_rep_id",
      "expected_revenue",
      "bant_budget",
      "bant_authority",
      "bant_need",
      "bant_timeline",
      "qualification",
      "monthly_revenue",
      "lead_temperature",
      "email_opted_out",
      "created_at",
      "updated_at"
    ]
  },
  "oportunidade": {
    "table": "deals",
    "plural": "oportunidades",
    "search": "title",
    "fields": [
      "lead_id",
      "title",
      "description",
      "pipeline_id",
      "pipeline_stage_id",
      "sales_rep_id",
      "sdr_id",
      "product_id",
      "original_price",
      "negotiated_price",
      "expected_close_date",
      "notes",
      "labels",
      "lost_reason"
    ],
    "required": [
      "lead_id",
      "title",
      "pipeline_id",
      "pipeline_stage_id"
    ],
    "read": [
      "id",
      "lead_id",
      "title",
      "description",
      "pipeline_id",
      "pipeline_stage_id",
      "sales_rep_id",
      "sdr_id",
      "product_id",
      "original_price",
      "negotiated_price",
      "expected_close_date",
      "notes",
      "labels",
      "lost_reason",
      "status",
      "won_at",
      "lost_at",
      "stage_changed_at",
      "created_at",
      "updated_at"
    ]
  },
  "tarefa": {
    "table": "company_activities",
    "plural": "tarefas",
    "search": "name",
    "fields": [
      "name",
      "description",
      "lead_id",
      "responsavel_id",
      "priority",
      "task_type",
      "due_datetime",
      "scheduled_at",
      "end_datetime",
      "notes",
      "completed",
      "outcome",
      "meeting_link",
      "status"
    ],
    "required": [
      "name"
    ],
    "read": [
      "id",
      "name",
      "description",
      "lead_id",
      "responsavel_id",
      "priority",
      "task_type",
      "due_datetime",
      "scheduled_at",
      "end_datetime",
      "notes",
      "completed",
      "outcome",
      "meeting_link",
      "created_at",
      "updated_at",
      "status",
      "completed_at"
    ]
  },
  "nota": {
    "table": "sales_notes",
    "plural": "notas",
    "search": "content",
    "fields": [
      "lead_id",
      "deal_id",
      "content",
      "note_type"
    ],
    "required": [
      "content"
    ],
    "read": [
      "id",
      "lead_id",
      "deal_id",
      "content",
      "note_type",
      "created_at",
      "updated_at"
    ]
  },
  "etapa": {
    "table": "sales_pipeline_stages",
    "plural": "etapas",
    "search": "name",
    "fields": [
      "pipeline_id",
      "name",
      "description",
      "position",
      "color",
      "is_won",
      "is_lost"
    ],
    "required": [
      "pipeline_id",
      "name",
      "position"
    ],
    "read": [
      "id",
      "pipeline_id",
      "name",
      "description",
      "position",
      "color",
      "is_won",
      "is_lost",
      "created_at",
      "updated_at"
    ]
  },
  "funil": {
    "table": "sales_pipelines",
    "plural": "funis",
    "search": "name",
    "fields": [
      "name",
      "description",
      "is_active",
      "color",
      "default_sales_rep_id"
    ],
    "required": [
      "name"
    ],
    "read": [
      "id",
      "name",
      "description",
      "is_active",
      "color",
      "default_sales_rep_id",
      "created_at",
      "updated_at"
    ]
  },
  "produto": {
    "table": "products",
    "plural": "produtos",
    "search": "name",
    "fields": [
      "name",
      "slug",
      "description",
      "price",
      "category",
      "sku",
      "is_active"
    ],
    "required": [
      "name",
      "slug"
    ],
    "read": [
      "id",
      "name",
      "slug",
      "description",
      "price",
      "category",
      "sku",
      "is_active",
      "created_at",
      "updated_at"
    ]
  },
  "campanha_email": {
    "table": "email_campaigns",
    "plural": "campanhas_email",
    "search": "name",
    "fields": [
      "name",
      "description",
      "subject",
      "from_name",
      "from_email",
      "reply_to",
      "html_content",
      "preheader",
      "template_id"
    ],
    "required": [
      "name"
    ],
    "read": [
      "id",
      "name",
      "description",
      "subject",
      "from_name",
      "from_email",
      "reply_to",
      "html_content",
      "preheader",
      "template_id",
      "status",
      "created_at",
      "updated_at"
    ]
  },
  "campanha_whatsapp": {
    "table": "campaigns",
    "plural": "campanhas_whatsapp",
    "search": "name",
    "fields": [
      "name",
      "description",
      "message_content"
    ],
    "required": [
      "name",
      "message_content"
    ],
    "read": [
      "id",
      "name",
      "description",
      "message_content",
      "status",
      "created_at",
      "updated_at"
    ]
  },
  "template_email": {
    "table": "email_templates",
    "plural": "templates_email",
    "search": "name",
    "fields": [
      "name",
      "subject",
      "html_content",
      "text_content",
      "preheader",
      "category",
      "variables",
      "is_active"
    ],
    "required": [
      "name"
    ],
    "read": [
      "id",
      "name",
      "subject",
      "html_content",
      "text_content",
      "preheader",
      "category",
      "variables",
      "is_active",
      "created_at",
      "updated_at"
    ]
  },
  "automacao_email": {
    "table": "email_automations",
    "plural": "automacoes_email",
    "search": "name",
    "fields": [
      "name",
      "description",
      "trigger_event",
      "trigger_filter",
      "flow_json"
    ],
    "required": [
      "name",
      "trigger_event"
    ],
    "read": [
      "id",
      "name",
      "description",
      "trigger_event",
      "trigger_filter",
      "flow_json",
      "is_active",
      "created_at",
      "updated_at"
    ]
  },
  "automacao_comercial": {
    "table": "sales_automation_rules",
    "plural": "automacoes_comerciais",
    "search": "name",
    "fields": [
      "name",
      "description",
      "trigger_type",
      "trigger_conditions",
      "action_type",
      "action_config",
      "priority"
    ],
    "required": [
      "name",
      "trigger_type",
      "action_type"
    ],
    "read": [
      "id",
      "name",
      "description",
      "trigger_type",
      "trigger_conditions",
      "action_type",
      "action_config",
      "priority",
      "is_active",
      "created_at",
      "updated_at"
    ]
  },
  "lista_email": {
    "table": "email_lists",
    "plural": "listas_email",
    "search": "name",
    "fields": [
      "name",
      "description",
      "criteria",
      "is_dynamic",
      "is_active"
    ],
    "required": [
      "name"
    ],
    "read": [
      "id",
      "name",
      "description",
      "criteria",
      "is_dynamic",
      "is_active",
      "created_at",
      "updated_at"
    ]
  },
  "membro": {
    "table": "team_members",
    "plural": "membros",
    "search": "name",
    "fields": [
      "name",
      "email",
      "role",
      "team",
      "is_active"
    ],
    "required": [],
    "read": [
      "id",
      "name",
      "email",
      "role",
      "team",
      "is_active",
      "created_at",
      "updated_at"
    ]
  }
} as const;
