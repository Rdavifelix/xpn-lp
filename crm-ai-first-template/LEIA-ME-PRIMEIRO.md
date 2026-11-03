# Comece aqui

1. Extraia o ZIP em uma pasta nova e abra essa pasta no seu assistente de programação.
2. Diga: “Instale meu CRM seguindo o setup.sh e depois configure a publicação e o MCP.”
3. Use suas contas Supabase e hospedagem. Reserve o endereço HTTPS da instalação antes do setup.
4. No terminal, informe as credenciais solicitadas. Não cole senhas ou chaves no chat.
5. Entre com o administrador criado pelo instalador e configure os serviços que pretende usar.

No Windows, execute o fluxo no WSL2/Ubuntu. No Mac/Linux, use o terminal normal.

Após o setup, siga docs/PUBLICAR_E_CONECTAR_MCP.md. Para retomar uma falha, preserve .installation-project.json e use o projeto ali indicado; não crie outro nem reaplique o baseline manualmente. O assistente deve conferir o estado antes de continuar.

Se você já possui um CRM, siga GUIA_UPGRADE.md em vez de setup.sh.
