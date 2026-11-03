const url=new URL(process.argv[2]);
if(url.protocol!=="https:"||url.username||url.password||url.search||url.hash||url.pathname!=="/"||url.hostname.endsWith(".example.com")||url.hostname==="example.com")throw new Error("Use a origem HTTPS real da sua instalação, sem caminho.");
console.log(url.origin);
