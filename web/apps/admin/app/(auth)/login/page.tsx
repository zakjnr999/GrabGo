"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Button, Input, Label, Card, useAuth } from "@grabgo/ui";
import { authService } from "@grabgo/utils";
import { ShieldCheck, WarningCircle, EyeClosed, Eye, NavArrowRight, Mail, Lock } from "iconoir-react";
import { Loader2 } from "lucide-react";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [isForgotPassword, setIsForgotPassword] = useState(false);
  const [resetEmailSent, setResetEmailSent] = useState(false);

  const { login, isAuthenticated, isLoading: authLoading } = useAuth(); // Modified useAuth destructuring
  const [error, setError] = useState<string | null>(null);
  const router = useRouter(); // Added router initialization

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && !authLoading) {
      router.push('/');
    }
  }, [isAuthenticated, authLoading, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Prevent concurrent submissions
    if (isLoading) return;

    setIsLoading(true);
    setError(null);

    try {
      // Client-side validation
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!email || !emailRegex.test(email)) {
        throw new Error('Please enter a valid email address');
      }

      if (!isForgotPassword && (!password || password.length < 6)) {
        throw new Error('Password must be at least 6 characters');
      }

      if (isForgotPassword) {
        // Handle password reset
        await authService.forgotPassword({ email });
        setResetEmailSent(true);
      } else {
        // Handle login
        await login({ email, password });
        // Redirect handled by AuthContext
      }
    } catch (err: any) {
      setError(err.message || 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  const handleForgotPasswordClick = () => {
    setIsForgotPassword(true);
    setResetEmailSent(false);
    setPassword("");
    setError(null); // Clear any previous errors
  };

  const handleBackToLogin = () => {
    setIsForgotPassword(false);
    setResetEmailSent(false);
    setEmail("");
    setPassword("");
    setError(null); // Clear any previous errors
  };

  return (
    <div className="min-h-screen w-full relative overflow-hidden bg-gradient-to-br from-background via-background to-secondary/20">
      {/* Animated Background Orbs - Subtle neutral */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-4 w-96 h-96 rounded-full blur-3xl animate-blob" style={{ background: 'radial-gradient(circle, rgba(150, 150, 150, 0.08) 0%, rgba(150, 150, 150, 0.02) 100%)' }} />
        <div className="absolute top-0 -right-4 w-96 h-96 rounded-full blur-3xl animate-blob animation-delay-2000" style={{ background: 'radial-gradient(circle, rgba(150, 150, 150, 0.06) 0%, transparent 100%)' }} />
        <div className="absolute -bottom-8 left-20 w-96 h-96 rounded-full blur-3xl animate-blob animation-delay-4000" style={{ background: 'radial-gradient(circle, rgba(150, 150, 150, 0.07) 0%, rgba(150, 150, 150, 0.01) 100%)' }} />
      </div>

      {/* Floating Grid Pattern - Enhanced visibility */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#80808018_1px,transparent_1px),linear-gradient(to_bottom,#80808018_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_80%_50%_at_50%_0%,#000_70%,transparent_100%)]" />

      <div className="relative z-10 flex min-h-screen items-center justify-center p-4">
        <div className="w-full max-w-6xl grid lg:grid-cols-2 gap-8 items-center">

          {/* Left Side - Branding Section */}
          <div className="hidden lg:flex flex-col justify-center space-y-6 animate-fade-in-left">
            <div className="space-y-4">
              {/* Logo with unique animation */}
              <div className="inline-flex items-center space-x-3 group">
                <div className="relative">
                  <div className="w-14 h-14 rounded-md flex items-center justify-center transform group-hover:scale-110 transition-transform duration-300 shadow-lg" style={{ background: 'linear-gradient(to bottom right, #FE6132, #ff7f50)', boxShadow: '0 10px 25px rgba(254, 97, 50, 0.3)' }}>
                    <ShieldCheck className="w-8 h-8 text-white" strokeWidth={2} />
                  </div>
                  <div className="absolute inset-0 rounded-md bg-primary/20 blur-xl group-hover:blur-2xl transition-all duration-300" />
                </div>
              </div>

              <h2 className="text-5xl font-bold leading-tight">
                <span className="text-foreground">Admin</span>
                <br />
                <span style={{ color: '#FE6132' }}>
                  Dashboard
                </span>
              </h2>

              <p className="text-lg text-muted-foreground max-w-md">
                Manage your delivery platform with powerful tools and real-time insights.
              </p>
            </div>

            {/* Animated Stats Cards - Unique feature */}
            <div className="grid grid-cols-2 gap-4 pt-8">
              {[
                { label: "Active Orders", value: "1,234", delay: "0ms" },
                { label: "Total Revenue", value: "GH₵45.2K", delay: "100ms" },
              ].map((stat, i) => (
                <Card
                  key={i}
                  className="p-4 border-primary/20 bg-card/60 backdrop-blur-sm hover:border-primary/40 transition-all duration-300 hover:shadow-xl hover:shadow-primary/10 hover:-translate-y-1 animate-fade-in-up"
                  style={{ animationDelay: stat.delay }}
                >
                  <div className="text-3xl font-bold" style={{ color: '#FE6132' }}>{stat.value}</div>
                  <div className="text-sm text-muted-foreground">{stat.label}</div>
                </Card>
              ))}
            </div>
          </div>

          {/* Right Side - Login Form */}
          <div className="w-full max-w-md mx-auto animate-fade-in-right">
            <Card className="p-8 border-primary/20 bg-card/90 backdrop-blur-xl shadow-2xl shadow-primary/10 hover:shadow-primary/15 transition-shadow duration-300">
              <div
                key={isForgotPassword ? (resetEmailSent ? 'success' : 'forgot') : 'login'}
                className="space-y-6 animate-fade-in"
              >
                {/* Header */}
                <div className="space-y-2 text-center lg:text-left">
                  <h3 className="text-2xl font-bold tracking-tight">
                    {resetEmailSent ? "Check your email" : isForgotPassword ? "Reset your password" : "Welcome back"}
                  </h3>
                  <p className="text-sm text-muted-foreground">
                    {resetEmailSent
                      ? "We've sent a password reset link to your email address"
                      : isForgotPassword
                        ? "Enter your email address and we'll send you a reset link"
                        : "Enter your credentials to access your account"}
                  </p>
                </div>

                {/* Error Message */}
                {error && (
                  <div
                    className="rounded-md p-4 animate-fade-in"
                    style={{
                      backgroundColor: 'rgba(254, 242, 242, 0.5)',
                      border: '1px solid rgba(254, 226, 226, 0.8)'
                    }}
                  >
                    <div className="flex items-start gap-3">
                      <div className="flex-shrink-0">
                        <WarningCircle className="w-5 h-5 mt-0.5" style={{ color: '#f87171' }} strokeWidth={2} />
                      </div>
                      <div className="flex-1">
                        <h3 className="text-sm font-semibold" style={{ color: '#dc2626' }}>
                          {error.includes('CORS') || error.includes('Network') || error.includes('Failed to fetch')
                            ? 'Connection Error'
                            : 'Authentication Failed'}
                        </h3>
                        <p className="mt-1 text-sm" style={{ color: '#ef4444' }}>
                          {error.includes('CORS') || error.includes('Network') || error.includes('Failed to fetch')
                            ? 'Unable to connect to the server. Please check your internet connection or try again later.'
                            : error}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Form */}
                <form onSubmit={handleSubmit} className="space-y-4">
                  {/* Email Field */}
                  <div className="space-y-2 group">
                    <Label htmlFor="email" className="text-sm font-medium">
                      Email Address
                    </Label>
                    <div className="relative">
                      <Input
                        id="email"
                        type="email"
                        placeholder="admin@grabgo.com"
                        value={email}
                        onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
                        className="h-11 pl-10 border-input transition-all duration-200"
                        style={{
                          outline: 'none',
                        }}
                        onFocus={(e: React.FocusEvent<HTMLInputElement>) => {
                          e.target.style.borderColor = '#FE6132';
                          e.target.style.boxShadow = '0 0 0 3px rgba(254, 97, 50, 0.15), 0 0 20px rgba(254, 97, 50, 0.1)';
                        }}
                        onBlur={(e: React.FocusEvent<HTMLInputElement>) => {
                          e.target.style.borderColor = '';
                          e.target.style.boxShadow = '';
                        }}
                        required
                      />
                      <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground group-focus-within:text-primary transition-colors" strokeWidth={2} />
                    </div>
                  </div>

                  {/* Password Field - Only show for login */}
                  {!isForgotPassword && !resetEmailSent && (
                    <div className="space-y-2 group">
                      <div className="flex items-center justify-between">
                        <Label htmlFor="password" className="text-sm font-medium">
                          Password
                        </Label>
                        <button
                          type="button"
                          onClick={handleForgotPasswordClick}
                          className="text-xs font-medium transition-colors"
                          style={{ color: '#FE6132' }}
                        >
                          Forgot password?
                        </button>
                      </div>
                      <div className="relative">
                        <Input
                          id="password"
                          type={showPassword ? "text" : "password"}
                          placeholder="••••••••"
                          value={password}
                          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPassword(e.target.value)}
                          className="h-11 pl-10 pr-10 border-input transition-all duration-200"
                          style={{
                            outline: 'none',
                          }}
                          onFocus={(e: React.FocusEvent<HTMLInputElement>) => {
                            e.target.style.borderColor = '#FE6132';
                            e.target.style.boxShadow = '0 0 0 3px rgba(254, 97, 50, 0.15), 0 0 20px rgba(254, 97, 50, 0.1)';
                          }}
                          onBlur={(e: React.FocusEvent<HTMLInputElement>) => {
                            e.target.style.borderColor = '';
                            e.target.style.boxShadow = '';
                          }}
                          required
                        />
                        <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground group-focus-within:text-primary transition-colors" strokeWidth={2} />
                        <button
                          type="button"
                          onClick={() => setShowPassword(!showPassword)}
                          className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                        >
                          {showPassword ? (
                            <EyeClosed className="w-5 h-5" strokeWidth={2} />
                          ) : (
                            <Eye className="w-5 h-5" strokeWidth={2} />
                          )}
                        </button>
                      </div>
                    </div>)}

                  {/* Submit Button with unique loading animation */}
                  {!resetEmailSent ? (
                    <Button
                      type="submit"
                      className="w-full h-11 text-white font-medium shadow-lg hover:shadow-xl transition-all duration-300 relative overflow-hidden group"
                      style={{ background: 'linear-gradient(135deg, #FE6132 0%, #ff7f50 100%)', boxShadow: '0 4px 14px rgba(254, 97, 50, 0.25)' }}
                      disabled={isLoading}
                    >
                      <span className="relative z-10 flex items-center justify-center gap-2">
                        {isLoading ? (
                          <>
                            <Loader2 className="animate-spin h-5 w-5" />
                            {isForgotPassword ? "Sending link..." : "Signing in..."}
                          </>
                        ) : (
                          <>
                            {isForgotPassword ? "Send reset link" : "Sign in"}
                            <NavArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" strokeWidth={2} />
                          </>
                        )}
                      </span>
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000" />
                    </Button>
                  ) : (
                    <Button
                      type="button"
                      onClick={handleBackToLogin}
                      className="w-full h-11 text-white font-medium shadow-lg hover:shadow-xl transition-all duration-300 relative overflow-hidden group"
                      style={{ background: 'linear-gradient(135deg, #FE6132 0%, #ff7f50 100%)', boxShadow: '0 4px 14px rgba(254, 97, 50, 0.25)' }}
                    >
                      <span className="relative z-10 flex items-center justify-center gap-2">
                        <NavArrowRight className="w-4 h-4 rotate-180" strokeWidth={2} />
                        Back to Login
                      </span>
                    </Button>
                  )}
                </form>

                {/* Footer */}
                <p className="text-center text-sm text-muted-foreground pt-4">
                  {isForgotPassword || resetEmailSent ? (
                    <button
                      onClick={handleBackToLogin}
                      className="font-medium transition-colors hover:opacity-80 flex items-center justify-center w-full gap-2"
                      style={{ color: '#FE6132' }}
                    >
                      <svg className="w-4 h-4 rotate-180" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                      </svg>
                      Back to login
                    </button>
                  ) : (
                    <>
                      Need help?{" "}
                      <button className="font-medium transition-colors" style={{ color: '#FE6132' }}>
                        Contact support
                      </button>
                    </>
                  )}
                </p>
              </div>
            </Card>

            {/* Mobile Logo */}
            <div className="lg:hidden flex justify-center mt-8 animate-fade-in">
              <div className="inline-flex items-center space-x-2 text-muted-foreground">
                <div className="w-8 h-8 rounded-md bg-primary/10 flex items-center justify-center">
                  <ShieldCheck className="w-5 h-5 text-primary" strokeWidth={2} />
                </div>
                <span className="text-sm font-medium">GrabGo Admin</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
