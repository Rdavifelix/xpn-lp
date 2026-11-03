import type { Config } from '@netlify/functions';
import { readConfig } from '../../mcp-server/src/auth.js';
import { createWebHandler } from '../../mcp-server/src/web.js';

export default async (req:Request) => {
  try {
    const config=readConfig({
      MCP_PUBLIC_URL:Netlify.env.get('MCP_PUBLIC_URL'),
      SUPABASE_URL:Netlify.env.get('SUPABASE_URL'),
      SUPABASE_PUBLISHABLE_KEY:Netlify.env.get('SUPABASE_PUBLISHABLE_KEY'),
      MCP_OAUTH_CLIENT_IDS:Netlify.env.get('MCP_OAUTH_CLIENT_IDS'),
      MCP_DYNAMIC_CLIENTS:Netlify.env.get('MCP_DYNAMIC_CLIENTS'),
    });
    return await createWebHandler(config)(req);
  } catch {
    return Response.json({error:'Conexão MCP em preparação.'},{status:503,headers:{'Cache-Control':'no-store'}});
  }
};
export const config:Config={path:['/mcp','/.well-known/oauth-protected-resource','/.well-known/oauth-protected-resource/mcp']};
