import { useEffect } from 'react';
import { useParams } from 'react-router-dom';

export default function CommunityRedirect() {
  const { slug = '' } = useParams<{ slug: string }>();

  useEffect(() => {
    if (!/^[a-zA-Z0-9_-]{1,100}$/.test(slug)) return;
    const baseUrl = import.meta.env.VITE_SUPABASE_URL;
    if (!baseUrl) return;
    window.location.replace(
      `${baseUrl}/functions/v1/community-redirect?s=${encodeURIComponent(slug)}`,
    );
  }, [slug]);

  return <div className="min-h-screen grid place-items-center">Redirecionando…</div>;
}
