// Helper isolado pra evitar import circular entre MailyEditor e maily-blocks-pt
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";

export async function uploadImage(file: Blob): Promise<string> {
  const ext = (file.type.split("/")[1] || "png").replace("jpeg", "jpg");
  const filename = `${crypto.randomUUID()}.${ext}`;
  const { error } = await supabase.storage
    .from("email-assets")
    .upload(filename, file, { contentType: file.type, upsert: false });
  if (error) {
    toast.error(`Erro ao fazer upload: ${error.message}`);
    throw error;
  }
  const { data } = supabase.storage.from("email-assets").getPublicUrl(filename);
  return data.publicUrl;
}
