import fundoImage from '../assets/fundo-locdecor.jpg';
import logo from '../assets/logo-card.png';
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Loader2, Eye, EyeOff } from 'lucide-react';

const Login = () => {
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const { signIn, signUp } = useAuth();
  const navigate = useNavigate();

  const validateForm = () => {
    if (!email || !password) {
      setError('Email e senha são obrigatórios');
      return false;
    }

    if (isSignUp && password !== confirmPassword) {
      setError('As senhas não coincidem');
      return false;
    }

    if (password.length < 6) {
      setError('A senha deve ter pelo menos 6 caracteres');
      return false;
    }

    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!validateForm()) return;

    setIsLoading(true);

    try {
      if (isSignUp) {
        await signUp(email, password);
        setSuccess('Conta criada com sucesso! Você já pode fazer login.');
        setIsSignUp(false);
        setPassword('');
        setConfirmPassword('');
      } else {
        await signIn(email, password);
        navigate('/');
      }
    } catch (err: any) {
      if (err.message === 'Invalid login credentials') {
        setError('Email ou senha incorretos');
      } else if (err.message.includes('User already registered')) {
        setError('Este email já está cadastrado');
      } else {
        setError(err.message);
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div
      className="min-h-screen bg-cover bg-center flex items-center justify-start px-40"
      style={{ backgroundImage: `url(${fundoImage})` }}
    >
      <div className="bg-[#122432]/80 backdrop-blur-md p-8 rounded-2xl shadow-2xl w-full max-w-md text-white">
        <img src={logo} alt="Logo LocDecor" className="mx-auto h-20 mb-6" />

        {error && (
          <div className="mb-4 p-3 bg-red-100 text-red-600 rounded-md text-sm">{error}</div>
        )}

        {success && (
          <div className="mb-4 p-3 bg-green-100 text-green-600 rounded-md text-sm">{success}</div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-2 rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-purple-600 bg-white text-black"
            required
          />

          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              placeholder="Senha"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2 rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-purple-600 bg-white text-black"
              required
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-2/4 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
            >
              {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
            </button>
          </div>

          {isSignUp && (
            <input
              type="password"
              placeholder="Confirmar senha"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="w-full px-4 py-2 rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-purple-600 bg-white text-black"
              required
            />
          )}

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-purple-600 text-white py-2 rounded-md hover:bg-purple-700 transition-colors disabled:opacity-50 flex items-center justify-center"
          >
            {isLoading ? (
              <>
                <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                {isSignUp ? 'Criando conta...' : 'Entrando...'}
              </>
            ) : (
              isSignUp ? 'Criar Conta' : 'Entrar'
            )}
          </button>
        </form>
      </div>
    </div>
  );
};

export default Login;
