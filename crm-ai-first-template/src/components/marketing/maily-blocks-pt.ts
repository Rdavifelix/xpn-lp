import {
  button,
  linkCard,
  htmlCodeBlock,
  image,
  logo,
  inlineImage,
  columns,
  section,
  repeat,
  spacer,
  divider,
  bulletList,
  orderedList,
  text,
  heading1,
  heading2,
  heading3,
  hardBreak,
  blockquote,
  footer,
  clearLine,
  type BlockGroupItem,
  type BlockItem,
} from '@maily-to/core/blocks';
import { uploadImage } from './maily-image-upload';
import { toast } from 'sonner';

// Bloco custom: abre file picker do computador, faz upload, insere imagem
const uploadImageBlock: BlockItem = {
  title: 'Imagem do computador',
  description: 'Sobe uma imagem do seu computador.',
  searchTerms: ['imagem', 'foto', 'upload', 'arquivo', 'pc', 'computador'],
  command: ({ editor, range }) => {
    // Remove o "/" e o range que vai virar imagem
    editor.chain().focus().deleteRange(range).run();

    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml';
    input.style.display = 'none';
    document.body.appendChild(input);

    input.addEventListener('change', async () => {
      const file = input.files?.[0];
      input.remove();
      if (!file) return;

      // Validações básicas
      const MAX_MB = 10;
      if (file.size > MAX_MB * 1024 * 1024) {
        toast.error(`Imagem maior que ${MAX_MB}MB. Comprima antes de subir.`);
        return;
      }

      const toastId = toast.loading('Subindo imagem…');
      try {
        const url = await uploadImage(file);
        toast.success('Imagem inserida', { id: toastId });
        editor.chain().focus().setImage({ src: url, alt: file.name } as any).run();
      } catch (err: any) {
        toast.error(`Falha no upload: ${err.message}`, { id: toastId });
      }
    });

    input.click();
  },
};

const t = (b: BlockItem, title: string, description?: string): BlockItem =>
  ({ ...b, title, description: description ?? b.description } as BlockItem);

export const blocksPtBR: BlockGroupItem[] = [
  {
    title: 'Conteúdo',
    commands: [
      t(text, 'Texto', 'Parágrafo simples.'),
      t(heading1, 'Título 1', 'Título de destaque.'),
      t(heading2, 'Título 2', 'Subtítulo.'),
      t(heading3, 'Título 3', 'Subtítulo menor.'),
      t(blockquote, 'Citação', 'Bloco de citação.'),
      t(footer, 'Rodapé', 'Texto pequeno de rodapé.'),
    ],
  },
  {
    title: 'Listas',
    commands: [
      t(bulletList, 'Lista com marcadores', 'Lista não ordenada.'),
      t(orderedList, 'Lista numerada', 'Lista ordenada.'),
    ],
  },
  {
    title: 'Mídia',
    commands: [
      uploadImageBlock,
      t(image, 'Imagem por URL', 'Cola o link de uma imagem.'),
      t(inlineImage, 'Imagem inline', 'Imagem dentro do texto.'),
      t(logo, 'Logo', 'Logo da marca.'),
    ],
  },
  {
    title: 'Layout',
    commands: [
      t(columns, 'Colunas', 'Layout em colunas.'),
      t(section, 'Seção', 'Bloco de seção.'),
      t(spacer, 'Espaçador', 'Espaço vertical.'),
      t(divider, 'Divisor', 'Linha divisória.'),
      t(repeat, 'Repetir', 'Bloco repetível.'),
      t(clearLine, 'Quebra de linha', 'Quebra de linha sem espaçamento.'),
      t(hardBreak, 'Nova linha', 'Quebra de linha forçada.'),
    ],
  },
  {
    title: 'Ações',
    commands: [
      t(button, 'Botão', 'Adiciona um botão de chamada para ação.'),
      t(linkCard, 'Card de link', 'Card clicável com link.'),
    ],
  },
  {
    title: 'Avançado',
    commands: [
      t(htmlCodeBlock, 'HTML personalizado', 'Insere um bloco de HTML customizado.'),
    ],
  },
];
