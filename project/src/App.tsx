import React from 'react';
import { BrowserRouter as Router, useLocation } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import AppRoutes from './routes';

const AppContent = () => {
  const [isSidebarOpen, setIsSidebarOpen] = React.useState(false);
  const location = useLocation();
  const isLoginPage = location.pathname === '/login';

  if (isLoginPage) {
    return <AppRoutes />;
  }

  return (
    <div className="flex h-screen bg-gray-100">
      {/* Mobile sidebar backdrop */}
      {isSidebarOpen && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 z-20 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}
      
      {/* Mobile menu button */}
      <button
        className="fixed top-4 left-4 z-30 lg:hidden bg-white p-2 rounded-lg shadow-md"
        onClick={() => setIsSidebarOpen(!isSidebarOpen)}
      >
        <svg
          className="w-6 h-6"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          {isSidebarOpen ? (
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          ) : (
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 6h16M4 12h16M4 18h16"
            />
          )}
        </svg>
      </button>

      {/* Sidebar */}
      <div className={`
        fixed inset-y-0 left-0 transform ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'}
        lg:relative lg:translate-x-0 transition duration-200 ease-in-out z-30 lg:z-0
        w-64 lg:w-64 lg:flex-shrink-0
      `}>
        <Sidebar onCloseMobile={() => setIsSidebarOpen(false)} />
      </div>

      {/* Main content */}
      <main className="flex-1 overflow-x-hidden overflow-y-auto lg:ml-0">
        <div className="lg:pt-0 pt-16">
          <AppRoutes />
        </div>
      </main>
    </div>
  );
};

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

export default App;