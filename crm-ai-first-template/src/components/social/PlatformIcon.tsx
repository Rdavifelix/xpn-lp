import { Instagram, Linkedin, Youtube, type LucideProps } from "lucide-react";
import type { Platform } from "@/hooks/useSocialPanel";
import { PLATFORM_COLOR } from "./shared";

/** O lucide não tem TikTok — desenhamos a nota musical no mesmo traço dos outros. */
function TikTok(props: LucideProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
    >
      <path d="M9 12a4 4 0 1 0 4 4V4a5 5 0 0 0 5 5" />
    </svg>
  );
}

const ICONES: Record<Platform, (p: LucideProps) => JSX.Element> = {
  instagram: Instagram,
  youtube: Youtube,
  linkedin: Linkedin,
  tiktok: TikTok,
};

/**
 * Ícone da rede na cor da marca. `emCor={false}` herda a cor do texto — usado nos
 * chips de filtro, onde o botão ativo já pinta o fundo e o ícone colorido brigaria
 * com ele.
 */
export function PlatformIcon({
  platform, className = "h-4 w-4", emCor = true,
}: {
  platform: Platform;
  className?: string;
  emCor?: boolean;
}) {
  const Icone = ICONES[platform];
  return <Icone className={className} style={emCor ? { color: PLATFORM_COLOR[platform] } : undefined} aria-hidden="true" />;
}
