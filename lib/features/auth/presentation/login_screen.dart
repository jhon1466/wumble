import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'auth_bloc.dart';
import '../../../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late VideoPlayerController _controller;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/login.mp4')
      ..initialize().then((_) {
        _controller.play();
        _controller.setLooping(true);
        _controller.setVolume(0.0);
        setState(() {});
      }).catchError((error) {
        debugPrint('Error inicializando video: $error');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Wumbleheme.backgroundColor,
      body: Stack(
        children: [
          // Video Background
          if (_controller.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          
          // Dark Overlay with Gradient (Lighter for better visibility)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                  Wumbleheme.backgroundColor.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 40),
                      // Logo or Icon
                      Transform.translate(
                        offset: Offset(0, 60),
                        child: Image.asset('assets/images/app_icon.png', height: 150),
                      ),
                      SizedBox(height: 16),
                      Image.asset(
                        'assets/images/app_name.png',
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                      Text(
                        _isLoginMode ? 'Inicia sesión para continuar' : 'Crea una cuenta nueva',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Wumbleheme.textSecondary),
                      ),
                      SizedBox(height: 40),
                      
                      // Form
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: tr('Correo electrónico'),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: tr('Contraseña'),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      BlocConsumer<AuthBloc, AuthState>(
                        listener: (context, state) {
                          if (state.status == AuthStatus.error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(state.errorMessage ?? 'Error')),
                            );
                          }
                        },
                        builder: (context, state) {
                          if (state.status == AuthStatus.loading) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                  onPressed: () {
                                    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(tr('Por favor llena todos los campos'))),
                                      );
                                      return;
                                    }
                                    
                                    if (_isLoginMode) {
                                      context.read<AuthBloc>().add(
                                            AuthLoginRequested(
                                              _emailController.text,
                                              _passwordController.text,
                                            ),
                                          );
                                    } else {
                                      context.read<AuthBloc>().add(
                                            AuthRegisterRequested(
                                              _emailController.text,
                                              _passwordController.text,
                                            ),
                                          );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Wumbleheme.secondaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _isLoginMode ? 'Iniciar Sesión' : 'Registrarse',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (_isLoginMode) ...[
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: Colors.white24)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        tr('O continúa con'),
                                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                      ),
                                    ),
                                    const Expanded(child: Divider(color: Colors.white24)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                 _RGBButtonWrapper(
                                   child: OutlinedButton.icon(
                                     onPressed: () {
                                       context.read<AuthBloc>().add(AuthGoogleLoginRequested());
                                     },
                                     icon: Image.network(
                                       'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_Color_Icon.svg/1024px-Google_Color_Icon.svg.png',
                                       height: 24,
                                       errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                                     ),
                                     label: Text(tr('Continuar con Google'), style: TextStyle(color: Colors.white)),
                                     style: OutlinedButton.styleFrom(
                                       backgroundColor: Colors.black, // Dark background to make RGB pop
                                       padding: const EdgeInsets.symmetric(vertical: 16),
                                       side: BorderSide.none, // Remove standard border to use the RGB one
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(12),
                                       ),
                                     ),
                                   ),
                                 ),
                                const SizedBox(height: 16),
                              ],
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoginMode = !_isLoginMode;
                                  });
                                },
                                child: Text(
                                  _isLoginMode
                                      ? '¿No tienes cuenta? Registrate'
                                      : '¿Ya tienes cuenta? Inicia Sesión',
                                  style: const TextStyle(color: Wumbleheme.accentColor),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RGBButtonWrapper extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  const _RGBButtonWrapper({required this.child, this.borderRadius = 12});

  @override
  State<_RGBButtonWrapper> createState() => _RGBButtonWrapperState();
}

class _RGBButtonWrapperState extends State<_RGBButtonWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(1.5), // Ancho del borde RGB
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: const [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.indigo,
                Colors.purpleAccent,
                Colors.red,
              ],
              stops: const [0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84, 1.0],
              transform: GradientRotation(_controller.value * 2 * 3.14159265),
            ),
            boxShadow: [
              BoxShadow(
                color: HSVColor.fromAHSV(1.0, _controller.value * 360, 1.0, 1.0).toColor().withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

