import { Card } from "@/components/ui/card";
import { Upload } from "lucide-react";

/**
 * Stub mínimo — wizard de importação de leads CSV pra campanhas.
 * Pacote original não veio com este componente. Implementar depois conforme necessidade.
 */
export default function ImportLeadsWizard() {
  return (
    <Card className="p-8 text-center text-muted-foreground">
      <Upload className="h-8 w-8 mx-auto mb-3 opacity-50" />
      <p className="text-sm font-medium">Importar leads via CSV</p>
      <p className="text-xs mt-1">Funcionalidade em construção. Por enquanto, importe leads pelo módulo de Leads.</p>
    </Card>
  );
}
