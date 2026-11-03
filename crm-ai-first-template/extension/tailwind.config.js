/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{ts,tsx,html}'],
  theme: {
    extend: {
      colors: {
        ink: '#0c0c0e',
        parchment: '#f8f6f1',
        amber: {
          DEFAULT: '#c8952e',
          light: '#e4b964',
        },
        sage: '#7a9182',
        rose: '#c4453a',
        moss: '#3a8a5c',
      },
      fontFamily: {
        sans: ['DM Sans', 'system-ui', 'sans-serif'],
        serif: ['Instrument Serif', 'Georgia', 'serif'],
      },
    },
  },
  plugins: [],
};
