import { useEffect, useRef, useState, useCallback, useMemo } from 'react';
import { useParams } from 'react-router-dom';
import { fetchPublicForm } from '@/hooks/useMarketingForms';
import type { MarketingForm, FormField, FormStyle } from '@/types/marketing-form.types';
import { resolveStyle, loadGoogleFont } from '@/types/marketing-form.types';
import { CAPITAL_OPTIONS } from '@/types/marketing-form.types';
import { PhoneInput } from 'react-international-phone';
import 'react-international-phone/style.css';

const BRAZILIAN_STATES = [
  'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS','MT',
  'PA','PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC','SE','SP','TO',
];

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;

// ── City Search Component ────────────────────────────────────────────
function CitySearchField({ cities, loading, disabled, value, onChange, placeholder, hasError, style: formStyle }: {
  cities: string[]; loading: boolean; disabled: boolean; value: string;
  onChange: (v: string) => void; placeholder: string; hasError: boolean; style: FormStyle;
}) {
  const [query, setQuery] = useState(value);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => { setQuery(value); }, [value]);
  useEffect(() => {
    const handler = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const filtered = useMemo(() => {
    if (!query.trim()) return cities.slice(0, 50);
    const q = query.toLowerCase();
    return cities.filter(c => c.toLowerCase().includes(q)).slice(0, 50);
  }, [cities, query]);

  const glass = formStyle.bg_color === 'transparent';
  const txtColor = glass ? '#ffffff' : formStyle.text_color;
  const bgColor = glass ? 'rgba(255,255,255,0.08)' : formStyle.bg_color;
  const borderClr = glass ? 'rgba(255,255,255,0.15)' : formStyle.text_color + '22';

  const iStyle: React.CSSProperties = {
    width: '100%', padding: '10px 14px',
    border: `1px solid ${hasError ? '#ef4444' : borderClr}`,
    borderRadius: formStyle.border_radius, fontSize: 14, fontFamily: formStyle.font_family,
    backgroundColor: bgColor, color: txtColor, outline: 'none',
    opacity: disabled ? 0.6 : 1,
  };

  return (
    <div ref={ref} style={{ position: 'relative' }}>
      <input
        style={iStyle}
        type="text"
        placeholder={loading ? 'Carregando cidades...' : disabled ? 'Selecione o estado primeiro' : placeholder}
        disabled={disabled || loading}
        value={query}
        onChange={e => { setQuery(e.target.value); onChange(''); setOpen(true); }}
        onFocus={() => { if (cities.length > 0) setOpen(true); }}
      />
      {open && filtered.length > 0 && (
        <div style={{
          position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 50,
          maxHeight: 200, overflowY: 'auto',
          backgroundColor: glass ? 'rgba(20,20,25,0.95)' : formStyle.bg_color,
          backdropFilter: glass ? 'blur(12px)' : undefined,
          border: `1px solid ${borderClr}`, borderRadius: formStyle.border_radius,
          boxShadow: '0 4px 12px rgba(0,0,0,0.2)', marginTop: 4,
        }}>
          {filtered.map(city => (
            <div key={city} style={{ padding: '8px 12px', cursor: 'pointer', fontSize: 14, color: txtColor }}
              onMouseEnter={e => (e.currentTarget.style.backgroundColor = glass ? 'rgba(255,255,255,0.1)' : `${formStyle.primary_color}10`)}
              onMouseLeave={e => (e.currentTarget.style.backgroundColor = 'transparent')}
              onClick={() => { onChange(city); setQuery(city); setOpen(false); }}
            >{city}</div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Helpers ──────────────────────────────────────────────────────────

// Inject phone input CSS overrides
if (typeof document !== 'undefined' && !document.getElementById('rip-overrides')) {
  const s = document.createElement('style');
  s.id = 'rip-overrides';
  s.textContent = `
    .react-international-phone-input-container { width: 100% !important; display: flex !important; }
    .react-international-phone-input { flex: 1 !important; }
    .react-international-phone-country-selector-button { margin: 0 !important; }
    .react-international-phone-country-selector-dropdown { z-index: 100 !important; }
  `;
  document.head.appendChild(s);
}

function phoneMask(value: string): string {
  const digits = value.replace(/\D/g, '').slice(0, 11);
  if (digits.length <= 2) return digits.length ? `(${digits}` : '';
  if (digits.length <= 7) return `(${digits.slice(0, 2)}) ${digits.slice(2)}`;
  return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`;
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function getTrackingParams(): Record<string, string> {
  const params: Record<string, string> = {};
  const search = new URLSearchParams(window.location.search);

  // UTM params
  const utmKeys = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term'];
  utmKeys.forEach((k) => {
    const v = search.get(k);
    if (v) params[k] = v;
  });

  // Click IDs (Google, Meta, TikTok, Bing, LinkedIn)
  const clickIds = ['gclid', 'fbclid', 'ttclid', 'msclkid', 'li_fat_id'];
  clickIds.forEach((k) => {
    const v = search.get(k);
    if (v) params[k] = v;
  });

  // Landing page URL (passed by embed script as _lp)
  const lp = search.get('_lp');
  if (lp) params.landing_page = lp;

  // Referrer (passed by embed script as _ref)
  const ref = search.get('_ref');
  if (ref) params.referrer = ref;

  // Fallback: try document.referrer if no UTMs found
  if (!params.utm_source && !params.gclid && !params.fbclid) {
    try {
      const refUrl = new URL(document.referrer);
      const refParams = new URLSearchParams(refUrl.search);
      utmKeys.forEach((k) => {
        const v = refParams.get(k);
        if (v && !params[k]) params[k] = v;
      });
      if (!params.referrer) params.referrer = document.referrer;
    } catch {
      // referrer may not be a valid URL
    }
  }

  return params;
}

function postHeight() {
  try {
    const height = document.body.scrollHeight;
    window.parent.postMessage({ type: 'np-form-height', height }, '*');
    // Backwards compat: embeds gerados antes de abr/2026 escutam o type antigo
    window.parent.postMessage({ type: 'crm-form-height', height }, '*');
  } catch {
    // cross-origin may block
  }
}

// ── Component ────────────────────────────────────────────────────────

export default function FormEmbed() {
  const { id } = useParams<{ id: string }>();
  const requestId=useRef(crypto.randomUUID());
  const [honeypot,setHoneypot]=useState('');
  const embedded=new URLSearchParams(window.location.search).get('embed')==='1';

  const [form, setForm] = useState<MarketingForm | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [values, setValues] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const [cities, setCities] = useState<string[]>([]);
  const [citiesLoading, setCitiesLoading] = useState(false);

  const [fadeIn, setFadeIn] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Set body transparent for embed
  useEffect(() => {
    document.body.style.margin = '0';
    document.body.style.padding = '0';
    document.body.style.background = 'transparent';
    document.documentElement.style.background = 'transparent';
  }, []);

  // Load Google Fonts Inter
  useEffect(() => {
    if (document.querySelector('link[data-np-font]')) return;
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap';
    link.setAttribute('data-np-font', '1');
    document.head.appendChild(link);
  }, []);

  // Fetch form config
  useEffect(() => {
    if (!id) {
      setError('ID do formulario nao informado.');
      setLoading(false);
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const data = await fetchPublicForm(id);
        if (cancelled) return;
        if (!data) {
          setError('Formulario nao encontrado ou inativo.');
        } else {
          setForm(data);
          // init hidden field values from defaults
          const initial: Record<string, string> = {};
          data.fields.forEach((f) => {
            if (f.type === 'hidden' && f.placeholder) initial[f.id] = f.placeholder;
          });
          setValues(initial);
        }
      } catch {
        if (!cancelled) setError('Erro ao carregar formulario.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [id]);

  // Fade in after loaded
  useEffect(() => {
    if (!loading && form) {
      requestAnimationFrame(() => setFadeIn(true));
    }
  }, [loading, form]);

  // Post height to parent
  useEffect(() => {
    postHeight();
    const observer = new ResizeObserver(() => postHeight());
    if (containerRef.current) observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, [loading, submitted, form]);

  // Load cities when state changes
  const selectedState = values['estado'] || Object.keys(values).reduce<string>((acc, key) => {
    const field = form?.fields.find((f) => f.id === key && f.type === 'state');
    return field ? values[key] : acc;
  }, '');

  useEffect(() => {
    if (!selectedState) { setCities([]); return; }
    let cancelled = false;
    setCitiesLoading(true);
    fetch(`https://servicodados.ibge.gov.br/api/v1/localidades/estados/${selectedState}/municipios`)
      .then((r) => r.json())
      .then((data: { nome: string }[]) => {
        if (!cancelled) {
          setCities(data.map((c) => c.nome).sort());
        }
      })
      .catch(() => { if (!cancelled) setCities([]); })
      .finally(() => { if (!cancelled) setCitiesLoading(false); });
    return () => { cancelled = true; };
  }, [selectedState]);

  // ── Handlers ─────────────────────────────────────────

  const setValue = useCallback((fieldId: string, val: string) => {
    setValues((prev) => ({ ...prev, [fieldId]: val }));
    setErrors((prev) => {
      const next = { ...prev };
      delete next[fieldId];
      return next;
    });
  }, []);

  const validate = useCallback((): boolean => {
    if (!form) return false;
    const newErrors: Record<string, string> = {};
    form.fields.forEach((f) => {
      const val = (values[f.id] || '').trim();
      if (f.required && !val) {
        newErrors[f.id] = 'Campo obrigatorio';
        return;
      }
      if (f.type === 'email' && val && !isValidEmail(val)) {
        newErrors[f.id] = 'Email invalido';
      }
      if (f.type === 'phone' && val) {
        const digits = val.replace(/\D/g, '');
        if (digits.length < 10) newErrors[f.id] = 'Telefone invalido';
      }
    });
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }, [form, values]);

  const handleSubmit = useCallback(async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form || !validate()) return;

    setSubmitting(true);

    const attributionParams=new URLSearchParams(window.location.search);
    const payload={request_id:requestId.current,values,tracking:{...(form.settings.auto_capture_utm?getTrackingParams():{}),crm_page:attributionParams.get('crm_page'),crm_session:attributionParams.get('crm_session')},website:honeypot};
    try {
      const res = await fetch(
        `${SUPABASE_URL}/functions/v1/public-form?id=${form.id}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        },
      );
      const result=await res.json();
      if (!res.ok || !result.ok) throw new Error(result.error || 'Erro ao enviar');

      setSubmitted(true);

      // Redirect or show success
      if (form.redirect_url) {
        setTimeout(() => {
          window.location.href = form.redirect_url!;
        }, 1500);
      }
    } catch (e) {
      setErrors({ _form: e instanceof Error?e.message:'Erro ao enviar. Tente novamente.' });
    } finally {
      setSubmitting(false);
    }
  }, [form, values, validate,honeypot]);

  // ── Styles ───────────────────────────────────────────

  const formStyle: FormStyle = form?.style || {
    primary_color: '#c8952e',
    bg_color: '#ffffff',
    text_color: '#1a1a1a',
    border_radius: 8,
    font_family: 'Inter, system-ui, sans-serif',
    button_text: 'Enviar',
    button_style: 'solid',
  };

  // 🎨 Resolve cores opcionais com fallback retro-compatível
  const resolved = resolveStyle(formStyle);

  // Carrega Google Font dinamicamente se for uma das catalogadas
  useEffect(() => {
    const firstFontName = (formStyle.font_family || '').split(',')[0].replace(/["']/g, '').trim();
    if (firstFontName) loadGoogleFont(firstFontName);
  }, [formStyle.font_family]);

  const compact = form?.settings.compact_mode ?? false;
  const gap = compact ? 12 : 16;
  const inputPadding = compact ? '10px 14px' : '12px 16px';
  // 16px previne zoom automático do Safari iOS ao focar input
  const fontSize = compact ? 15 : 16;

  const borderColor = `${formStyle.text_color}22`;
  const focusRing = `0 0 0 2px ${formStyle.primary_color}44`;

  // Button styles — agora usam button_color/button_text_color resolvidos
  const btnBase: React.CSSProperties = {
    width: '100%',
    padding: compact ? '10px 16px' : '12px 20px',
    fontSize: compact ? 15 : 16,
    fontWeight: 600,
    fontFamily: formStyle.font_family,
    borderRadius: formStyle.border_radius,
    cursor: submitting ? 'wait' : 'pointer',
    transition: 'all 0.2s ease',
    border: 'none',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    opacity: submitting ? 0.7 : 1,
  };

  const btnStyles: Record<string, React.CSSProperties> = {
    solid: {
      ...btnBase,
      background: resolved.button_bg,
      color: resolved.button_text,
    },
    outline: {
      ...btnBase,
      background: 'transparent',
      color: resolved.button_text,
      border: `2px solid ${resolved.button_bg}`,
    },
    gradient: {
      ...btnBase,
      background: `linear-gradient(135deg, ${resolved.button_bg}, ${resolved.button_bg}cc)`,
      color: resolved.button_text,
    },
  };

  // ── Render Helpers ─────────────────────────────────────

  const isGlass = formStyle.bg_color === 'transparent';

  // Inputs agora usam input_bg_color / input_text_color resolvidos
  const inputStyle = (hasError: boolean): React.CSSProperties => ({
    width: '100%',
    padding: inputPadding,
    fontSize,
    fontFamily: formStyle.font_family,
    color: isGlass ? '#ffffff' : resolved.input_text,
    background: isGlass ? 'rgba(255,255,255,0.08)' : resolved.input_bg,
    border: `1px solid ${hasError ? '#e53e3e' : isGlass ? 'rgba(255,255,255,0.15)' : borderColor}`,
    borderRadius: formStyle.border_radius,
    outline: 'none',
    transition: 'border-color 0.2s, box-shadow 0.2s',
    boxSizing: 'border-box' as const,
  });

  const labelStyle: React.CSSProperties = {
    display: 'block',
    marginBottom: 4,
    fontSize: fontSize - 1,
    fontWeight: 500,
    color: isGlass ? 'rgba(255,255,255,0.9)' : resolved.label,
    fontFamily: formStyle.font_family,
  };

  const errorTextStyle: React.CSSProperties = {
    fontSize: 12,
    color: '#e53e3e',
    marginTop: 2,
    fontFamily: formStyle.font_family,
  };

  const renderField = (field: FormField) => {
    if (field.type === 'hidden') {
      return (
        <input
          key={field.id}
          type="hidden"
          name={field.map_to || field.id}
          value={values[field.id] || field.placeholder || ''}
        />
      );
    }

    const hasError = !!errors[field.id];
    const common = {
      id:field.id,
      name:field.id,
      'aria-label':field.label,
      'aria-required':field.required,
      style: inputStyle(hasError),
      onFocus: (e: React.FocusEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
        e.currentTarget.style.borderColor = formStyle.primary_color;
        e.currentTarget.style.boxShadow = focusRing;
      },
      onBlur: (e: React.FocusEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
        e.currentTarget.style.borderColor = hasError ? '#e53e3e' : borderColor;
        e.currentTarget.style.boxShadow = 'none';
      },
    };

    let input: React.ReactNode;

    switch (field.type) {
      case 'instagram':
      case 'text':
        input = (
          <input
            type="text"
            placeholder={field.placeholder}
            value={values[field.id] || ''}
            onChange={(e) => setValue(field.id, e.target.value)}
            {...common}
          />
        );
        break;

      case 'email':
        input = (
          <input
            type="email"
            placeholder={field.placeholder}
            value={values[field.id] || ''}
            onChange={(e) => setValue(field.id, e.target.value)}
            {...common}
          />
        );
        break;

      case 'phone':
        input = (
          <div style={{ width: '100%' }}>
            <PhoneInput
              inputProps={{id:field.id,'aria-label':field.label,'aria-required':field.required}}
              defaultCountry="br"
              value={values[field.id] || ''}
              onChange={(phone) => setValue(field.id, phone)}
              style={{ width: '100%' }}
              inputStyle={{
                width: '100%', height: 48, padding: '0 14px', fontSize: 16,
                fontFamily: formStyle.font_family,
                backgroundColor: isGlass ? 'rgba(255,255,255,0.08)' : resolved.input_bg,
                color: isGlass ? '#ffffff' : resolved.input_text,
                border: `1px solid ${hasError ? '#ef4444' : isGlass ? 'rgba(255,255,255,0.15)' : formStyle.text_color + '22'}`,
                borderLeft: 'none',
                borderRadius: `0 ${formStyle.border_radius}px ${formStyle.border_radius}px 0`,
                outline: 'none',
              }}
              countrySelectorStyleProps={{
                buttonStyle: {
                  height: 48,
                  border: `1px solid ${hasError ? '#ef4444' : isGlass ? 'rgba(255,255,255,0.15)' : formStyle.text_color + '22'}`,
                  borderRight: 'none',
                  borderRadius: `${formStyle.border_radius}px 0 0 ${formStyle.border_radius}px`,
                  backgroundColor: isGlass ? 'rgba(255,255,255,0.05)' : resolved.input_bg,
                  padding: '0 6px 0 10px',
                },
              }}
            />
          </div>
        );
        break;

      case 'number':
        input = (
          <input
            type="text"
            inputMode="numeric"
            placeholder={field.placeholder}
            value={values[field.id] || ''}
            onChange={(e) => {
              const num = e.target.value.replace(/\D/g, '');
              setValue(field.id, num);
            }}
            {...common}
          />
        );
        break;

      case 'select':
        input = (
          <select
            value={values[field.id] || ''}
            onChange={(e) => setValue(field.id, e.target.value)}
            {...common}
            style={{ ...inputStyle(hasError), appearance: 'none' as const, backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 8L1 3h10z'/%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 12px center' }}
          >
            <option value="">{field.placeholder || 'Selecione'}</option>
            {(field.options || []).map((opt) => (
              <option key={opt} value={opt}>{opt}</option>
            ))}
          </select>
        );
        break;

      case 'state':
        input = (
          <select
            value={values[field.id] || ''}
            onChange={(e) => {
              setValue(field.id, e.target.value);
              // Clear city fields when state changes
              form?.fields.forEach((f) => {
                if (f.type === 'city') setValue(f.id, '');
              });
            }}
            {...common}
            style={{ ...inputStyle(hasError), appearance: 'none' as const, backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 8L1 3h10z'/%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 12px center' }}
          >
            <option value="">{field.placeholder || 'Selecione o estado'}</option>
            {BRAZILIAN_STATES.map((uf) => (
              <option key={uf} value={uf}>{uf}</option>
            ))}
          </select>
        );
        break;

      case 'city':
        input = (
          <CitySearchField
            cities={cities}
            loading={citiesLoading}
            disabled={!selectedState}
            value={values[field.id] || ''}
            onChange={(v) => setValue(field.id, v)}
            placeholder={field.placeholder || 'Digite para buscar...'}
            hasError={hasError}
            style={formStyle}
          />
        );
        break;

      case 'capital':
        input = (
          <select
            value={values[field.id] || ''}
            onChange={(e) => setValue(field.id, e.target.value)}
            {...common}
            style={{ ...inputStyle(hasError), appearance: 'none' as const, backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 8L1 3h10z'/%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 12px center' }}
          >
            <option value="">{field.placeholder || 'Selecione'}</option>
            {CAPITAL_OPTIONS.map((opt) => (
              <option key={opt} value={opt}>{opt}</option>
            ))}
          </select>
        );
        break;

      case 'textarea':
        input = (
          <textarea
            placeholder={field.placeholder}
            value={values[field.id] || ''}
            onChange={(e) => setValue(field.id, e.target.value)}
            rows={3}
            {...common}
            style={{ ...inputStyle(hasError), resize: 'vertical' as const, minHeight: 80 }}
          />
        );
        break;

      default:
        input = null;
    }

    return (
      <div
        key={field.id}
        style={{
          gridColumn: field.width === 'half' ? 'span 1' : '1 / -1',
          minWidth: 0,
        }}
      >
        <label htmlFor={field.id} style={labelStyle}>
          {field.label}
          {field.required && <span style={{ color: '#e53e3e', marginLeft: 2 }}>*</span>}
        </label>
        {input}
        {hasError && <div style={errorTextStyle}>{errors[field.id]}</div>}
      </div>
    );
  };

  // ── Loading State ──────────────────────────────────────

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 200, fontFamily: 'Inter, system-ui, sans-serif' }}>
        <div style={{ width: 28, height: 28, border: '3px solid #e0e0e0', borderTopColor: '#888', borderRadius: '50%', animation: 'chspin 0.7s linear infinite' }} />
        <style>{`@keyframes chspin { to { transform: rotate(360deg); } }`}</style>
      </div>
    );
  }

  // ── Error State ────────────────────────────────────────

  if (error || !form) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 200, fontFamily: 'Inter, system-ui, sans-serif', color: '#666', padding: 24, textAlign: 'center' }}>
        {error || 'Formulario nao encontrado.'}
      </div>
    );
  }

  // ── Success State ──────────────────────────────────────

  if (submitted) {
    return (
      <div
        ref={containerRef}
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: 200,
          padding: 32,
          fontFamily: formStyle.font_family,
          color: isGlass ? '#ffffff' : formStyle.text_color,
          background: isGlass ? 'rgba(15,15,20,0.75)' : formStyle.bg_color,
          backdropFilter: isGlass ? 'blur(16px) saturate(1.2)' : undefined,
          WebkitBackdropFilter: isGlass ? 'blur(16px) saturate(1.2)' : undefined,
          border: isGlass ? '1px solid rgba(255,255,255,0.1)' : undefined,
          borderRadius: isGlass ? 16 : formStyle.border_radius,
          textAlign: 'center',
          animation: 'chfadein 0.4s ease',
          maxWidth: 640,
          margin: '0 auto',
          boxSizing: 'border-box' as const,
        }}
      >
        <div style={{
          width: 56,
          height: 56,
          borderRadius: '50%',
          background: `${formStyle.primary_color}18`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 16,
          animation: 'chpop 0.5s ease',
        }}>
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={formStyle.primary_color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M20 6L9 17l-5-5" style={{ strokeDasharray: 30, strokeDashoffset: 30, animation: 'chdraw 0.5s ease 0.3s forwards' }} />
          </svg>
        </div>
        <div style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          {form.success_message || 'Enviado com sucesso!'}
        </div>
        {form.redirect_url && (
          <div style={{ fontSize: 13, color: isGlass ? 'rgba(255,255,255,0.5)' : `${formStyle.text_color}88`, marginTop: 4 }}>Redirecionando...</div>
        )}
        <style>{`
          @keyframes chfadein { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
          @keyframes chpop { 0% { transform: scale(0); } 60% { transform: scale(1.15); } 100% { transform: scale(1); } }
          @keyframes chdraw { to { stroke-dashoffset: 0; } }
        `}</style>
      </div>
    );
  }

  // ── Form ───────────────────────────────────────────────

  return (
    <div
      ref={containerRef}
      style={{
        fontFamily: formStyle.font_family,
        color: formStyle.bg_color === 'transparent' ? '#ffffff' : formStyle.text_color,
        background: formStyle.bg_color === 'transparent'
          ? 'rgba(15, 15, 20, 0.75)'
          : formStyle.bg_color,
        backdropFilter: formStyle.bg_color === 'transparent' ? 'blur(16px) saturate(1.2)' : undefined,
        WebkitBackdropFilter: formStyle.bg_color === 'transparent' ? 'blur(16px) saturate(1.2)' : undefined,
        border: formStyle.bg_color === 'transparent' ? '1px solid rgba(255,255,255,0.1)' : undefined,
        borderRadius: formStyle.bg_color === 'transparent' ? 16 : formStyle.border_radius,
        padding: compact ? 16 : 28,
        opacity: fadeIn ? 1 : 0,
        transform: fadeIn ? 'translateY(0)' : 'translateY(8px)',
        transition: 'opacity 0.4s ease, transform 0.4s ease',
        width: '100%',
        maxWidth: 640,
        margin: embedded?'0 auto':'48px auto',
        boxSizing: 'border-box' as const,
      }}
      className="ch-form-container"
    >
      {/* Logo */}
      {form.settings.show_logo && formStyle.logo_url && (
        <div style={{ textAlign: 'center', marginBottom: gap }}>
          <img
            src={formStyle.logo_url}
            alt="Logo"
            style={{ maxHeight: 48, maxWidth: 200, objectFit: 'contain' }}
          />
        </div>
      )}

      <header style={{marginBottom:24}}><h1 style={{fontSize:26,fontWeight:700,margin:'0 0 8px'}}>{form.name}</h1>{form.description&&<p style={{opacity:.75,fontSize:14}}>{form.description}</p>}</header>
      <form onSubmit={handleSubmit} noValidate>
        <div aria-hidden="true" style={{position:'absolute',left:-10000}}><input tabIndex={-1} autoComplete="off" name="website" value={honeypot} onChange={e=>setHoneypot(e.target.value)}/></div>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(2, 1fr)',
            gap,
          }}
        >
          {form.fields.map(renderField)}
        </div>

        {/* Form-level error */}
        {errors._form && (
          <div style={{ ...errorTextStyle, marginTop: 12, textAlign: 'center', fontSize: 14 }}>
            {errors._form}
          </div>
        )}

        {/* Submit button */}
        <div style={{ marginTop: gap + 4 }}>
          <button
            type="submit"
            disabled={submitting}
            style={btnStyles[formStyle.button_style] || btnStyles.solid}
            onMouseEnter={(e) => {
              if (!submitting) e.currentTarget.style.opacity = '0.85';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.opacity = submitting ? '0.7' : '1';
            }}
          >
            {submitting && (
              <div style={{ width: 16, height: 16, border: '2px solid rgba(255,255,255,0.3)', borderTopColor: '#fff', borderRadius: '50%', animation: 'chspin 0.7s linear infinite' }} />
            )}
            {formStyle.button_text || 'Enviar'}
          </button>
        </div>
      </form>

      <style>{`
        @keyframes chspin { to { transform: rotate(360deg); } }
        /* Reset minimal pra iframe — evita scroll horizontal e zoom */
        html, body { margin: 0; padding: 0; overflow-x: hidden; -webkit-text-size-adjust: 100%; }
        body { background: transparent; }
        @media (max-width: 480px) {
          .ch-form-container {
            padding: 18px !important;
            border-radius: 14px !important;
          }
          div[style*="grid-template-columns"] { grid-template-columns: 1fr !important; }
          div[style*="grid-column: span 1"] { grid-column: 1 / -1 !important; }
          /* Inputs maiores e legíveis no mobile */
          .ch-form-container input,
          .ch-form-container select,
          .ch-form-container textarea {
            font-size: 16px !important;
            min-height: 44px;
          }
          .ch-form-container button[type="submit"] {
            min-height: 48px;
            font-size: 16px !important;
          }
        }
      `}</style>
    </div>
  );
}
