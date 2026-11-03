import { Globe } from 'lucide-react';

const networks: Record<string, [string, string]> = {
  instagram: ['instagram', '#D62976'], facebook: ['facebook', '#1877F2'],
  linkedin: ['linkedin', '#0A66C2'], twitter: ['x', 'currentColor'],
  tiktok: ['tiktok', 'currentColor'], youtube: ['youtube', '#E62117'],
  pinterest: ['pinterest', '#BD081C'], reddit: ['reddit', '#E83F00'],
  bluesky: ['bluesky', '#0085FF'], threads: ['threads', 'currentColor'],
  googlebusiness: ['google', '#4285F4'], snapchat: ['snapchat', 'currentColor'],
  telegram: ['telegram', '#229ED9'], whatsapp: ['whatsapp', '#168B46'],
  discord: ['discord', '#5865F2'], slack: ['slack', '#7C3085'],
  metaads: ['meta', '#0866FF'], googleads: ['googleads', '#4285F4'],
  linkedinads: ['linkedin', '#0A66C2'], tiktokads: ['tiktok', 'currentColor'],
  pinterestads: ['pinterest', '#BD081C'], xads: ['x', 'currentColor'],
  openaiads: ['openai', 'currentColor'], shopify: ['shopify', '#648526'],
};

/** Local brand assets: no third-party requests or tracking on the settings page. */
export function NetworkIcon({ platform }: { platform: string }) {
  const network = networks[platform.toLowerCase()];
  return <span aria-hidden="true" className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border bg-muted/40">
    {network ? <span className="block h-5 w-5" style={{
      backgroundColor: network[1],
      mask: `url(/social-icons/${network[0]}.svg) center / contain no-repeat`,
      WebkitMask: `url(/social-icons/${network[0]}.svg) center / contain no-repeat`,
    }} /> : <Globe className="h-5 w-5 text-muted-foreground" />}
  </span>;
}
