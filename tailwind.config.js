/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1464F4', // Azul Principal
          dark: '#0A2A6E',    // Azul Oscuro
          light: '#E8F0FF',   // Azul Claro (fondos)
        },
        status: {
          success: '#17A162', // Verde
          error: '#D93025',   // Rojo
          warning: '#F4D76B', // Amarillo
        },
        neutral: {
          text: '#1A1A1A',
          gray: '#555555',
          border: '#E5E5E5',
          bg: '#F7F9FC',
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      boxShadow: {
        'card': '0 2px 8px rgba(0, 0, 0, 0.05)',
        'card-hover': '0 4px 12px rgba(20, 100, 244, 0.1)',
      }
    },
  },
  plugins: [],
}
