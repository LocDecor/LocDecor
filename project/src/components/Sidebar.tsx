import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Users, 
  Package, 
  ShoppingCart, 
  Wallet,
  CheckSquare,
  LogOut
} from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

interface SidebarProps {
  onCloseMobile?: () => void;
}

const Sidebar: React.FC<SidebarProps> = ({ onCloseMobile }) => {
  const { signOut } = useAuth();
  const navigate = useNavigate();

  const menuItems = [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/' },
    { icon: Users, label: 'Clientes', path: '/clientes' },
    { icon: ShoppingCart, label: 'Pedidos', path: '/pedidos' },
    { icon: Wallet, label: 'Financeiro', path: '/financeiro' },
    { icon: CheckSquare, label: 'Tarefas', path: '/tarefas' },
    { icon: Package, label: 'Acervo', path: '/acervo' },
  ];

  const handleClick = () => {
    if (onCloseMobile) {
      onCloseMobile();
    }
  };

  const handleLogout = async () => {
    try {
      await signOut();
      navigate('/login');
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  return (
    <div className="flex flex-col h-full bg-white border-r">
      <div className="flex items-center justify-center h-16 border-b">
        <h1 className="text-2xl font-bold text-purple-600">LocDecor</h1>
      </div>
      
      <nav className="flex-1 overflow-y-auto">
        <ul className="p-4 space-y-2">
          {menuItems.map((item) => (
            <li key={item.path}>
              <NavLink
                to={item.path}
                onClick={handleClick}
                className={({ isActive }) =>
                  `flex items-center px-4 py-3 text-gray-600 rounded-lg hover:bg-purple-50 hover:text-purple-600 transition-colors ${
                    isActive ? 'bg-purple-50 text-purple-600' : ''
                  }`
                }
              >
                <item.icon className="w-5 h-5 mr-3" />
                <span>{item.label}</span>
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      <div className="p-4 border-t">
        <button
          onClick={handleLogout}
          className="flex items-center w-full px-4 py-2 text-gray-600 rounded-lg hover:bg-red-50 hover:text-red-600 transition-colors"
        >
          <LogOut className="w-5 h-5 mr-3" />
          <span>Sair</span>
        </button>
      </div>
    </div>
  );
};

export default Sidebar;