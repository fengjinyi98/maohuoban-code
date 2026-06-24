-- 移除已下线的今日照护产品名称。
UPDATE legal_documents
SET html = REPLACE(
    html,
    '平台提供的“今日照护”及“疫苗驱虫提醒”属于非诊疗性质的日常关爱辅助工具。',
    '平台提供的日常记录与疫苗驱虫提醒属于非诊疗性质的日常关爱辅助工具。'
)
WHERE kind = 'user_agreement';
