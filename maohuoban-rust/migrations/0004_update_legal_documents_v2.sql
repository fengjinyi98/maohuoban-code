-- Remove bottom border/divider from legal documents meta section
UPDATE legal_documents
SET html = REPLACE(html, 'border-bottom: 0.5px solid var(--sep);', '');

UPDATE legal_documents
SET html = REPLACE(html, 'padding-bottom: var(--s4);', '');
