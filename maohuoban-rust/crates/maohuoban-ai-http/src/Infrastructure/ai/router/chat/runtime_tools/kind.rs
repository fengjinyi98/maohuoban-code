//! RuntimePetContextToolKind 运行时宠物上下文工具类型
//! 核心职责：
//! - 声明宠物上下文工具的身份标识和元数据
//! - 为每种工具提供 name、scope、fact_schema 等稳定映射

use maohuoban_ai_domain::ai::{AiFactStrength, ToolFactField, ToolFactSchema, ToolProgressText};

/// RuntimePetContextToolKind 运行时宠物上下文工具类型
/// 核心职责：
/// - 枚举宠物上下文工具类型
/// - 每种类型携带完整的工具元数据和事实 schema
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum RuntimePetContextToolKind {
    Identity,
    AbnormalEpisodeFacts,
    CurrentDiet,
    RecentHealthFacts,
    FoodInventoryHints,
    DietConfirmationCandidates,
    PrepareObservationWrite,
    PrepareAbnormalSymptomCreation,
    PrepareAbnormalRecoveryWrite,
    CommitObservationWrite,
    CommitAbnormalRecoveryWrite,
    SaveAbnormalFollowupPlan,
}

impl RuntimePetContextToolKind {
    pub(super) fn all() -> [Self; 12] {
        [
            Self::Identity,
            Self::AbnormalEpisodeFacts,
            Self::CurrentDiet,
            Self::RecentHealthFacts,
            Self::FoodInventoryHints,
            Self::DietConfirmationCandidates,
            Self::PrepareObservationWrite,
            Self::PrepareAbnormalSymptomCreation,
            Self::PrepareAbnormalRecoveryWrite,
            Self::CommitObservationWrite,
            Self::CommitAbnormalRecoveryWrite,
            Self::SaveAbnormalFollowupPlan,
        ]
    }

    pub(super) fn name(self) -> &'static str {
        match self {
            Self::Identity => "load_pet_identity_context",
            Self::AbnormalEpisodeFacts => "load_pet_abnormal_episode_facts",
            Self::CurrentDiet => "load_pet_current_diet_context",
            Self::RecentHealthFacts => "load_pet_recent_health_facts",
            Self::FoodInventoryHints => "load_food_inventory_change_hints",
            Self::DietConfirmationCandidates => "load_pet_diet_confirmation_candidates",
            Self::PrepareObservationWrite => "prepare_pet_observation_write",
            Self::PrepareAbnormalSymptomCreation => "prepare_pet_abnormal_symptom_creation",
            Self::PrepareAbnormalRecoveryWrite => "prepare_pet_abnormal_recovery_write",
            Self::CommitObservationWrite => "commit_pet_observation_write",
            Self::CommitAbnormalRecoveryWrite => "commit_pet_abnormal_recovery_write",
            Self::SaveAbnormalFollowupPlan => "save_abnormal_episode_followup_plan",
        }
    }

    pub(super) fn description(self) -> &'static str {
        match self {
            Self::Identity => {
                "加载目标宠物身份档案上下文。调用成功后前端会基于工具结果渲染宠物资料卡，最终正文应避免重复列出品种、性别、生日、年龄、来到世界天数和到家陪伴天数等资料卡字段，只补充用户问题需要的解释、观察或确认问题"
            }
            Self::AbnormalEpisodeFacts => {
                "加载目标宠物异常 episode 追踪事实，只返回异常 episode、父异常记录、追加观察、恢复、就诊关联和附件存在性，不返回便便、精神、食欲 quick facts"
            }
            Self::CurrentDiet => "加载目标宠物当前饮食上下文",
            Self::RecentHealthFacts => "加载目标宠物近期健康快捷事实",
            Self::FoodInventoryHints => "加载目标宠物储物柜变化弱线索",
            Self::DietConfirmationCandidates => "加载目标宠物饮食待确认候选",
            Self::PrepareObservationWrite => "准备写入宠物观察记录并创建确认任务",
            Self::PrepareAbnormalSymptomCreation => {
                "准备创建宠物异常追踪确认任务。模型整理异常发生时间、症状类型、程度和记录内容，用户授权前不会写入真实异常事件或 episode"
            }
            Self::PrepareAbnormalRecoveryWrite => {
                "准备将当前异常 episode 标记为恢复的确认任务。用户授权前不会写入恢复记录，也不会关闭追踪"
            }
            Self::CommitObservationWrite => "在用户确认后提交宠物观察记录写入",
            Self::CommitAbnormalRecoveryWrite => "在用户确认后提交异常恢复写入并关闭本次异常追踪",
            Self::SaveAbnormalFollowupPlan => {
                "保存异常 episode 主动追踪计划草稿。episode 和 followup 归属只能来自后端会话上下文，模型只提交 due_at、追问文案、规划理由和推荐动作"
            }
        }
    }

    pub(super) fn scope(self) -> &'static str {
        match self {
            Self::Identity => "pet.identity.read",
            Self::AbnormalEpisodeFacts => "pet.abnormal_episode.read",
            Self::CurrentDiet => "pet.current_diet.read",
            Self::RecentHealthFacts => "pet.recent_health_facts.read",
            Self::FoodInventoryHints => "food_inventory_change_hints.read",
            Self::DietConfirmationCandidates => "pet.diet_confirmation_candidates.read",
            Self::PrepareObservationWrite => "pet.observation.write_prepare",
            Self::PrepareAbnormalSymptomCreation => "pet.abnormal_symptom.create_prepare",
            Self::PrepareAbnormalRecoveryWrite => "pet.abnormal_recovery.write_prepare",
            Self::CommitObservationWrite => "pet.observation.write_commit",
            Self::CommitAbnormalRecoveryWrite => "pet.abnormal_recovery.write_commit",
            Self::SaveAbnormalFollowupPlan => "pet.abnormal_followup_plan.write",
        }
    }

    pub(super) fn requested_scope(self) -> &'static str {
        match self {
            Self::Identity => "pet_identity",
            Self::AbnormalEpisodeFacts => "pet_abnormal_episode",
            Self::CurrentDiet => "pet_current_diet",
            Self::RecentHealthFacts => "pet_recent_health_facts",
            Self::FoodInventoryHints => "food_inventory_change_hints",
            Self::DietConfirmationCandidates => "pet_diet_confirmation_candidates",
            Self::PrepareObservationWrite => "pet_observation_write_prepare",
            Self::PrepareAbnormalSymptomCreation => "pet_abnormal_symptom_create_prepare",
            Self::PrepareAbnormalRecoveryWrite => "pet_abnormal_recovery_write_prepare",
            Self::CommitObservationWrite => "pet_observation_write_commit",
            Self::CommitAbnormalRecoveryWrite => "pet_abnormal_recovery_write_commit",
            Self::SaveAbnormalFollowupPlan => "pet_abnormal_followup_plan_write",
        }
    }

    pub(super) fn domain_tag(self) -> &'static str {
        match self {
            Self::Identity => "identity",
            Self::AbnormalEpisodeFacts
            | Self::PrepareAbnormalSymptomCreation
            | Self::PrepareAbnormalRecoveryWrite
            | Self::CommitAbnormalRecoveryWrite => "abnormal_episode",
            Self::CurrentDiet => "diet",
            Self::RecentHealthFacts => "health",
            Self::FoodInventoryHints => "inventory",
            Self::DietConfirmationCandidates => "diet_confirmation",
            Self::PrepareObservationWrite | Self::CommitObservationWrite => "observation",
            Self::SaveAbnormalFollowupPlan => "abnormal_followup_plan",
        }
    }

    pub(super) fn progress_text(self) -> ToolProgressText {
        match self {
            Self::Identity => ToolProgressText {
                started: "正在加载宠物档案".to_owned(),
                completed: "宠物档案加载完成".to_owned(),
            },
            Self::AbnormalEpisodeFacts => ToolProgressText {
                started: "正在加载异常追踪".to_owned(),
                completed: "异常追踪加载完成".to_owned(),
            },
            Self::CurrentDiet => ToolProgressText {
                started: "正在加载饮食上下文".to_owned(),
                completed: "饮食上下文加载完成".to_owned(),
            },
            Self::RecentHealthFacts => ToolProgressText {
                started: "正在加载近期健康记录".to_owned(),
                completed: "近期健康记录加载完成".to_owned(),
            },
            Self::FoodInventoryHints => ToolProgressText {
                started: "正在加载储物柜线索".to_owned(),
                completed: "储物柜线索加载完成".to_owned(),
            },
            Self::DietConfirmationCandidates => ToolProgressText {
                started: "正在加载饮食待确认候选".to_owned(),
                completed: "饮食待确认候选加载完成".to_owned(),
            },
            Self::PrepareObservationWrite => ToolProgressText {
                started: "正在准备观察记录写入".to_owned(),
                completed: "观察记录确认任务已准备".to_owned(),
            },
            Self::PrepareAbnormalSymptomCreation => ToolProgressText {
                started: "正在准备异常追踪".to_owned(),
                completed: "异常追踪确认任务已准备".to_owned(),
            },
            Self::PrepareAbnormalRecoveryWrite => ToolProgressText {
                started: "正在准备恢复记录".to_owned(),
                completed: "恢复确认任务已准备".to_owned(),
            },
            Self::CommitObservationWrite => ToolProgressText {
                started: "正在提交观察记录写入".to_owned(),
                completed: "观察记录写入完成".to_owned(),
            },
            Self::CommitAbnormalRecoveryWrite => ToolProgressText {
                started: "正在提交恢复记录".to_owned(),
                completed: "恢复记录写入完成".to_owned(),
            },
            Self::SaveAbnormalFollowupPlan => ToolProgressText {
                started: "正在保存追踪计划".to_owned(),
                completed: "追踪计划已保存".to_owned(),
            },
        }
    }

    pub(super) fn fact_schema(self) -> ToolFactSchema {
        match self {
            Self::Identity => identity_fact_schema(),
            Self::AbnormalEpisodeFacts => abnormal_episode_fact_schema(),
            Self::CurrentDiet => diet_fact_schema(),
            Self::RecentHealthFacts => health_quick_fact_schema(),
            Self::FoodInventoryHints => inventory_hint_fact_schema(),
            Self::DietConfirmationCandidates => confirmation_candidate_fact_schema(),
            Self::PrepareObservationWrite => observation_write_prepare_fact_schema(),
            Self::PrepareAbnormalRecoveryWrite => observation_write_prepare_fact_schema(),
            Self::PrepareAbnormalSymptomCreation => abnormal_symptom_creation_prepare_fact_schema(),
            Self::CommitObservationWrite | Self::CommitAbnormalRecoveryWrite => {
                observation_write_commit_fact_schema()
            }
            Self::SaveAbnormalFollowupPlan => abnormal_followup_plan_fact_schema(),
        }
    }
}

/// identity_fact_schema 宠物身份事实 schema
fn identity_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec![
            "pet_identity.name".to_owned(),
            "pet_identity.species".to_owned(),
            "pet_identity.sex".to_owned(),
            "pet_identity.breed".to_owned(),
            "pet_identity.birthday".to_owned(),
            "pet_identity.arrival_date".to_owned(),
            "pet_identity.world_days".to_owned(),
            "pet_identity.companionship_days".to_owned(),
        ],
        description: "宠物身份事实".to_owned(),
        natural_language_summary:
            "可回答目标宠物的名字、物种、性别、品种、生日、年龄/来到世界天数、到家时间、陪伴天数等基础档案问题"
                .to_owned(),
        fields: vec![
            ToolFactField {
                key: "pet_identity.birthday".to_owned(),
                label: "生日".to_owned(),
                meaning: "宠物出生日期，可用于回答生日、出生日期、年龄相关问题".to_owned(),
                example_queries: vec!["生日是什么时候".to_owned(), "哪天出生的".to_owned()],
            },
            ToolFactField {
                key: "pet_identity.world_days".to_owned(),
                label: "年龄/出生至今天数".to_owned(),
                meaning: "宠物从生日到今天经过的天数，可用于回答多大了、几岁了、出生多久了、来到世界多少天"
                    .to_owned(),
                example_queries: vec![
                    "多大了".to_owned(),
                    "几岁了".to_owned(),
                    "出生多久了".to_owned(),
                    "来到世界多少天".to_owned(),
                ],
            },
            ToolFactField {
                key: "pet_identity.arrival_date".to_owned(),
                label: "到家时间".to_owned(),
                meaning: "宠物来到用户身边或到家的日期".to_owned(),
                example_queries: vec!["什么时候到家的".to_owned(), "什么时候来我身边的".to_owned()],
            },
            ToolFactField {
                key: "pet_identity.companionship_days".to_owned(),
                label: "陪伴天数".to_owned(),
                meaning: "宠物从到家日期到今天陪伴用户的天数".to_owned(),
                example_queries: vec!["陪伴我多久了".to_owned(), "到家多久了".to_owned()],
            },
        ],
        default_strength: Some(AiFactStrength::Strong),
    }
}

/// diet_fact_schema 当前饮食事实 schema
fn diet_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec![
            "diet.current_staple".to_owned(),
            "diet.trying_food".to_owned(),
            "diet.usual_treat".to_owned(),
            "diet.usual_nutrition".to_owned(),
            "diet.recent_feeding".to_owned(),
            "diet.recent_diet_change".to_owned(),
        ],
        description: "宠物当前饮食事实".to_owned(),
        natural_language_summary:
            "可回答目标宠物当前主粮、尝试中食品、常用零食/营养品、最近喂食记录等已确认饮食事实"
                .to_owned(),
        fields: vec![
            ToolFactField {
                key: "diet.current_staple".to_owned(),
                label: "当前主粮".to_owned(),
                meaning: "宠物当前正在吃的主粮食品名，已确认的饮食配置".to_owned(),
                example_queries: vec![
                    "现在吃什么".to_owned(),
                    "主粮是什么".to_owned(),
                    "最近在吃什么粮".to_owned(),
                ],
            },
            ToolFactField {
                key: "diet.recent_feeding".to_owned(),
                label: "最近喂食".to_owned(),
                meaning: "宠物最近喂食的食品名和时间，可用于回答最近吃了什么".to_owned(),
                example_queries: vec!["最近吃了什么".to_owned(), "最近喂了什么".to_owned()],
            },
        ],
        default_strength: Some(AiFactStrength::Strong),
    }
}

/// health_quick_fact_schema 健康快捷事实 schema
fn health_quick_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["health.recent_quick_fact".to_owned()],
        description: "宠物近期健康快捷事实".to_owned(),
        natural_language_summary:
            "可回答目标宠物近期便便是否正常、精神状态是否正常、食欲是否正常等已确认快捷记录"
                .to_owned(),
        fields: vec![ToolFactField {
            key: "health.recent_quick_fact".to_owned(),
            label: "近期健康快捷记录".to_owned(),
            meaning: "宠物近期便便、精神、食欲等快捷记录标题、摘要、类型和发生时间".to_owned(),
            example_queries: vec![
                "今天便便正常吗".to_owned(),
                "精神怎么样".to_owned(),
                "食欲正常吗".to_owned(),
            ],
        }],
        default_strength: Some(AiFactStrength::Strong),
    }
}

/// abnormal_episode_fact_schema 异常 episode 追踪事实 schema
fn abnormal_episode_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec![
            "health.abnormal_episode.status".to_owned(),
            "health.abnormal_episode.initial_event".to_owned(),
            "health.abnormal_episode.timeline".to_owned(),
            "health.abnormal_episode.attachments".to_owned(),
            "health.abnormal_episode.followup_gap".to_owned(),
        ],
        description: "宠物异常 episode 追踪事实".to_owned(),
        natural_language_summary:
            "可回答异常 episode 的状态、父异常记录、追加观察、恢复和附件存在性".to_owned(),
        fields: vec![
            ToolFactField {
                key: "health.abnormal_episode.status".to_owned(),
                label: "异常追踪状态".to_owned(),
                meaning: "异常 episode 当前状态，例如追踪中、已恢复或已归档".to_owned(),
                example_queries: vec!["这个异常现在怎么样了".to_owned(), "异常恢复了吗".to_owned()],
            },
            ToolFactField {
                key: "health.abnormal_episode.initial_event".to_owned(),
                label: "父异常记录".to_owned(),
                meaning: "触发 episode 的原始异常事件，包含发生时间、摘要和附件存在性".to_owned(),
                example_queries: vec!["最早是哪条异常".to_owned(), "一开始记录了什么".to_owned()],
            },
            ToolFactField {
                key: "health.abnormal_episode.timeline".to_owned(),
                label: "追踪时间线".to_owned(),
                meaning: "异常 episode 下的追加观察、恢复、就诊关联等事件序列".to_owned(),
                example_queries: vec![
                    "后续追加了哪些观察".to_owned(),
                    "进展时间线是什么".to_owned(),
                ],
            },
            ToolFactField {
                key: "health.abnormal_episode.attachments".to_owned(),
                label: "附件存在性".to_owned(),
                meaning: "异常父记录和追加观察是否存在照片等附件，用于判断证据是否完整".to_owned(),
                example_queries: vec!["有照片吗".to_owned(), "追加观察有没有附件".to_owned()],
            },
            ToolFactField {
                key: "health.abnormal_episode.followup_gap".to_owned(),
                label: "追踪间隔".to_owned(),
                meaning: "最近一次追加观察或异常记录距离当前的时间间隔，用于判断是否需要继续追踪"
                    .to_owned(),
                example_queries: vec!["多久没追踪了".to_owned(), "还需要补观察吗".to_owned()],
            },
        ],
        default_strength: Some(AiFactStrength::Strong),
    }
}

/// inventory_hint_fact_schema 储物柜变化弱线索 schema
fn inventory_hint_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["food_inventory.change_hint".to_owned()],
        description: "储物柜变化弱线索".to_owned(),
        natural_language_summary:
            "只提供储物柜近期变化线索（新增/消耗食品），这些是弱线索，不能作为已发生喂食事实。回答时必须标注为待确认线索"
                .to_owned(),
        fields: vec![ToolFactField {
            key: "food_inventory.change_hint".to_owned(),
            label: "储物柜变化".to_owned(),
            meaning: "近期储物柜食品新增或消耗的变化线索，只能作为弱提示，不可当已确认事实".to_owned(),
            example_queries: vec![
                "最近有什么新食物".to_owned(),
                "储物柜有什么变化".to_owned(),
            ],
        }],
        default_strength: Some(AiFactStrength::Weak),
    }
}

/// confirmation_candidate_fact_schema 饮食待确认候选 schema
fn confirmation_candidate_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["diet.confirmation_candidate".to_owned()],
        description: "饮食待确认候选".to_owned(),
        natural_language_summary:
            "提供从聊天和储物柜变化中抽取的待确认饮食候选。这些不是已发生事实，只能作为追问候选，需要用户确认后才能升级为强事实"
                .to_owned(),
        fields: vec![ToolFactField {
            key: "diet.confirmation_candidate".to_owned(),
            label: "饮食待确认候选".to_owned(),
            meaning: "从聊天或储物柜变化抽取的可能饮食变化，待用户确认后才能当作事实".to_owned(),
            example_queries: vec![
                "有什么需要我确认的".to_owned(),
                "最近饮食有什么变化".to_owned(),
            ],
        }],
        default_strength: Some(AiFactStrength::PendingConfirmation),
    }
}

fn observation_write_prepare_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["observation.write_prepare".to_owned()],
        description: "观察记录写提案".to_owned(),
        natural_language_summary: "创建结构化确认任务，等待用户确认后才能真正写入宠物观察记录"
            .to_owned(),
        fields: vec![ToolFactField {
            key: "observation.write_prepare".to_owned(),
            label: "观察记录写提案".to_owned(),
            meaning: "生成确认问题和确认任务 ID，不直接写入真实事件".to_owned(),
            example_queries: vec!["帮我记一下今天拉稀".to_owned()],
        }],
        default_strength: Some(AiFactStrength::PendingConfirmation),
    }
}

fn abnormal_symptom_creation_prepare_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["abnormal_symptom.create_prepare".to_owned()],
        description: "异常追踪创建提案".to_owned(),
        natural_language_summary:
            "创建异常父记录确认任务，等待用户确认后才能真正写入异常事件和 episode".to_owned(),
        fields: vec![ToolFactField {
            key: "abnormal_symptom.create_prepare".to_owned(),
            label: "异常追踪创建提案".to_owned(),
            meaning: "生成确认问题和确认任务 ID，不直接写入真实异常事件".to_owned(),
            example_queries: vec![
                "我的宠物昨天精神不好".to_owned(),
                "帮我记录这个异常".to_owned(),
            ],
        }],
        default_strength: Some(AiFactStrength::PendingConfirmation),
    }
}

fn observation_write_commit_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["observation.write_commit".to_owned()],
        description: "观察记录写提交结果".to_owned(),
        natural_language_summary: "在用户确认后真正写入宠物观察记录，并返回写入结果".to_owned(),
        fields: vec![ToolFactField {
            key: "observation.write_commit".to_owned(),
            label: "观察记录已写入".to_owned(),
            meaning: "确认后已落真实 pet event 的写入结果".to_owned(),
            example_queries: vec!["确认写入上一条观察记录".to_owned()],
        }],
        default_strength: Some(AiFactStrength::Strong),
    }
}

fn abnormal_followup_plan_fact_schema() -> ToolFactSchema {
    ToolFactSchema {
        fact_keys: vec!["abnormal_followup_plan.saved".to_owned()],
        description: "异常主动追踪计划保存结果".to_owned(),
        natural_language_summary: "保存经后端校验的异常 episode 下一轮主动追踪计划，不写入病情事实"
            .to_owned(),
        fields: vec![ToolFactField {
            key: "abnormal_followup_plan.saved".to_owned(),
            label: "追踪计划已保存".to_owned(),
            meaning: "异常 episode 的下一轮追踪计划已保存到 agent_proactive_followups".to_owned(),
            example_queries: vec!["安排下一次异常追踪".to_owned()],
        }],
        default_strength: Some(AiFactStrength::Strong),
    }
}
