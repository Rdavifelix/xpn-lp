/**
 * Biblioteca de Processos — dados publicados (seed)
 *
 * Este arquivo é a fonte de verdade do conteúdo publicado para todos os
 * visitantes. A estrutura está vazia de propósito: o conteúdo real
 * (categorias, pastas e arquivos) será injetado aqui na fase de "seed".
 *
 * Como publicar conteúdo novo:
 *   1. Como administrador, monte/edite a estrutura pela própria interface.
 *   2. Menu "Dados" (rodapé da barra lateral) → "Exportar seed (JSON)".
 *   3. Substitua o objeto abaixo pelo JSON exportado (o export já vem com
 *      `version` incrementada) e faça commit.
 *
 * Sempre que `version` aumentar, navegadores sem edições locais passam a
 * usar automaticamente estes dados.
 *
 * Hierarquia esperada:
 *   categories: [{ id, name, folders: [{ id, name, files: [{ id, title,
 *     content (HTML), published (bool), createdAt, updatedAt }] }] }]
 */
window.XPN_BIBLIOTECA_SEED = {
  version: 1,
  categories: []
};
