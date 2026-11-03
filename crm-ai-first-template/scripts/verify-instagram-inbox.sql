-- Read-only contract check for the columns used by inbox list and chat.
BEGIN;
SELECT count(*) AS readable_conversations FROM (
 SELECT c.id,c.is_ignored,c.last_message_at,c.status,s.slug,l.name,l.phone,l.instagram,l.sales_score,l.sales_stage,a.instagram_username,a.profile_picture_url
 FROM public.instagram_conversations c
 LEFT JOIN public.social_seller_stages s ON s.id=c.social_seller_stage_id
 LEFT JOIN public.leads l ON l.id=c.lead_id
 LEFT JOIN public.instagram_business_accounts a ON a.id=c.account_id
 WHERE c.status='open' AND c.is_ignored=false LIMIT 1
) sample;
SELECT count(*) AS readable_messages FROM (SELECT id,conversation_id,metadata,sent_at FROM public.instagram_messages LIMIT 1) sample;
ROLLBACK;
