import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './components/App.jsx'
import { AppProvider } from './context/AppContext.jsx'
import './styles/main.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <AppProvider>
      <App />
    </AppProvider>
  </React.StrictMode>,
)