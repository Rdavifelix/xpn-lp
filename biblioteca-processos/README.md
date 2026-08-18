# Biblioteca de Processos

Sistema de gestão do conhecimento no estilo Notion, publicado como app estático em
`https://maquinadereunioes.com/biblioteca-processos/`.

## Interface

- **Menu lateral principal (rail)** com o item "Biblioteca de Processos" e a área do usuário (login/logout).
- **Barra lateral interna** com busca e a árvore **Categorias → Pastas → Arquivos** em estilo accordion (recolhível).
- **Área principal** de leitura/edição com breadcrumb, título e **editor de texto rico**
  (títulos, negrito, itálico, sublinhado, tachado, listas, citação, links, divisor), com salvamento automático.
- Layout responsivo: no mobile a árvore vira um drawer.

## Permissões (RBAC)

| Papel | Acesso |
| --- | --- |
| **ADMINISTRADOR** | CRUD completo. Botões visíveis: "Nova Categoria", "Nova Pasta", "Novo Arquivo", além de renomear, excluir, publicar/despublicar e exportar/importar dados. |
| **Visitante (padrão)** | Somente leitura. Vê apenas arquivos **publicados** (e as pastas/categorias que os contêm). Nenhum botão de edição aparece. |

Login de administrador: botão "Visitante" no rodapé do menu lateral (ou "Acesso de administrador"
no rodapé da árvore). A senha padrão é **`xpn2026`** — troque-a substituindo a constante
`ADMIN_PASSWORD_SHA256` no topo de `app.js` (gere o hash com `printf 'nova-senha' | sha256sum`).

> Este site é 100% estático: a checagem de senha é client-side e controla apenas a interface.
> Ela evita edição casual, mas não é segurança de servidor — não guarde segredos nos documentos.

## Dados: estado local + seed publicado

Como não há backend, os dados funcionam em duas camadas:

1. **`seed-data.js`** — conteúdo publicado, versionado no repositório. É o que todo visitante vê.
2. **`localStorage`** — cópia de trabalho do navegador. Edições do administrador ficam locais
   até serem "publicadas" via seed.

### Fluxo para publicar conteúdo (seed)

1. Entre como administrador e monte/edite categorias, pastas e arquivos pela interface
   (ou use **Dados → Importar JSON…** para injetar tudo de uma vez).
2. Abra **Dados → Exportar seed (JSON)** — baixa `biblioteca-seed.json` já com `version` incrementada.
3. Substitua o objeto `window.XPN_BIBLIOTECA_SEED` em `seed-data.js` pelo JSON exportado e faça commit.
4. Navegadores sem edições locais adotam a nova versão automaticamente; administradores com
   edições locais recebem um aviso para escolher entre manter ou atualizar.

### Estrutura do JSON

```json
{
  "version": 2,
  "categories": [
    {
      "id": "…", "name": "Comercial",
      "folders": [
        {
          "id": "…", "name": "Scripts",
          "files": [
            {
              "id": "…", "title": "Follow-up",
              "content": "<p>HTML do documento</p>",
              "published": true,
              "createdAt": "2026-08-18T12:00:00.000Z",
              "updatedAt": "2026-08-18T12:00:00.000Z"
            }
          ]
        }
      ]
    }
  ]
}
```

O `content` é HTML sanitizado (tags permitidas: p, h1–h3, b/strong, i/em, u, s, ul/ol/li,
a, blockquote, hr, br, code, div, span).

## Arquivos

| Arquivo | Papel |
| --- | --- |
| `index.html` | Casca da interface + sprite de ícones SVG |
| `styles.css` | Tema claro estilo Notion + identidade XPN |
| `app.js` | Estado, RBAC, árvore, roteador (`#/arquivo/<id>`), editor e CRUD |
| `seed-data.js` | Conteúdo publicado (fonte de verdade para visitantes) |

## Desenvolvimento local

```bash
python3 -m http.server 4173
# http://localhost:4173/biblioteca-processos/
```
