# Guia de estilo — vídeos verticais (referência: "home service nos EUA")

Análise dos 3 vídeos de referência (`01-tecnicos-capacidade`, `02-concorrentes-menores`, `04-near-me-top3`).
Formato: 1080×1920, 30 fps, ~57–60 s, talking head gravado em frente a persiana com parede verde.

## 1. Legendas (padrão em todos os vídeos)

| Item | Padrão |
|---|---|
| Blocos | 2 a 4 palavras por vez, sem pontuação, sempre centralizadas |
| Fonte | Grotesca tipo Helvetica/SF, peso médio, ~70 px (reproduzido com **Inter 500**) |
| Dinâmica | Palavra a palavra ("karaokê"): as palavras já faladas ficam na cor cheia, as ainda não faladas ficam apagadas |
| Sobre o vídeo | Branco com sombra suave; não faladas em branco 55 % |
| Sobre fundo claro | Preto `#1C1C1E`; não faladas em cinza `#A3AAB1` |
| Palavras-chave | Azul `#2BA8E0` quando faladas, azul claro `#9AD9F3` antes (Google, Maps, top 3, ligações, faturamento, formulário, nomes de cidade, números…) |
| Posição | Vídeo cheio: centro em ~57 % da altura (y≈1095). Layouts gráficos: logo acima do vídeo em moldura (y≈1010) ou abaixo do card do mapa (y≈1240) |
| Entrada | Pequeno pop (escala 0,92→1 em ~120 ms) a cada bloco novo |

## 2. Os 4 layouts que se alternam

1. **Vídeo cheio** – talking head preenchendo a tela. Pode receber: chip no topo ("HOME SERVICE NOS EUA") e notificações empilhadas estilo iOS logo abaixo da legenda.
2. **Card + moldura** – fundo azul-claro degradê com linhas curvas sutis; card branco (raio 28 px, sombra suave) no terço superior com a ilustração; o vídeo encolhe para uma moldura 780×480 (raio 26 px, borda 4 px azul) na parte inferior.
3. **Mapa + avatar redondo** – card de mapa (grade de ruas branca sobre cinza, manchas verdes, rio azul) com pins/zonas; o vídeo vira um círculo de 300 px com borda azul sobreposto ao canto inferior direito do card.
4. **Número grande** – sem vídeo. Rótulo pequeno em azul ("Mês passado"), número gigante Montserrat ExtraBold azul ("US$ 150 mil"), subtítulo preto ("em faturamento") e chips abaixo ("100 % GRÁTIS").

A transição entre layouts é um movimento contínuo (~0,45 s): o vídeo encolhe/cresce até a nova posição enquanto o fundo claro surge e o card entra subindo com fade.

## 3. Componentes gráficos encontrados

| Componente | Onde aparece | Detalhes |
|---|---|---|
| Chip de topo | abertura | pill branco, Montserrat 700 22 px, caixa alta, letter-spacing |
| Ranking | "concorrentes menores acima de você" | título, 3 linhas com número em círculo azul, 5 estrelas amarelas, badge vermelho "CAIU PARA 3°" / setas verdes |
| Notificações | "perder serviços", "ligações chegando", "+1 perfil" | cards brancos 880×120, ícone redondo (X vermelho, telefone verde, pin azul), título 38 px, subtítulo cinza, "agora" à direita; entram deslizando de baixo, uma a cada ~0,8 s |
| Mapa | "cidades ou regiões mais distantes", "4 perfis no top 3" | zona azul em volta do pin preto "SEU ENDEREÇO", etiquetas #1 #2 #3 azuis; zonas vermelhas #14 #18; faixa vermelha inclinada "SEU PERFIL NÃO CHEGA AQUI"; pins azuis com pulso; nuvem de pontos azuis ("ranquear todas as localizações") |
| Perfil do Google | "otimizar o perfil / o site" | card "Sua empresa" com estrelas cinza → amarelas 4,9, badge verde OTIMIZADO, janela do site surgindo atrás |
| Celular | "vai no Google e pesquisa" | mockup de iPhone, campo de busca digitando "contractor near me", lista de resultados A/B/C, badge vermelho "VOCÊ NÃO APARECE" |
| Onde você aparece | "quinta ou terceira página" | lista de posições #4 #5 Página 2 Página 3 com badge "NINGUÉM TE VÊ" |
| Donut | "fatia orgânica do mercado" | anel azul crescendo com chips TOP 3 / Você |
| Agenda da equipe | vídeo 01 | tabela técnicos × horários com slots azuis preenchendo, badge "HORÁRIOS VAGOS" |
| Barras | "ligações chegando" | gráfico de barras azul crescendo, badge "CAPACIDADE SOBRANDO" |
| Logos riscados | "sem depender de Google, Meta, Yelp, Angi" | 4 ícones de app com X vermelho aparecendo um a um |
| CTA final | últimos 10 s | card navy `#0B1726`, "É só tocar em" + botão pill azul "Saiba mais" com cursor que clica; depois lista 1-2-3 (preencha o formulário / entramos em contato / explicamos como funciona) e seta para baixo |

## 4. Paleta e tipografia

| Token | Valor |
|---|---|
| Azul principal | `#2BA8E0` |
| Azul apagado | `#9AD9F3` |
| Vermelho | `#E8515A` |
| Verde | `#22C55E` |
| Amarelo (estrelas) | `#F5C518` |
| Preto texto | `#1C1C1E` |
| Cinza texto | `#A3AAB1` / `#6B7280` |
| Navy (CTA) | `#0B1726` |
| Fundo claro | degradê `#F4FAFC → #E6F3F8 → #D5ECF4` |
| Fonte UI | Montserrat 500/600/700/800 |
| Fonte legenda | Inter 500 (equivalente ao Helvetica da referência) |

## 5. Ritmo de edição

- Troca de layout a cada 4–8 s, sempre acompanhando o assunto da fala (problema → mapa, prova → números, fechamento → CTA).
- Elementos internos entram em cascata (0,12–0,25 s entre itens) e os badges "pop" exatamente na palavra correspondente.
- Nenhum corte no áudio; o vídeo bruto roda contínuo e só muda de enquadramento.
