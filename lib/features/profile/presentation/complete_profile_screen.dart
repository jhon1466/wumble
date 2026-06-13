import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme.dart';
import '../../../../injection_container.dart';
import '../../../../core/utils/media_helper.dart';
import '../domain/user_model.dart';
import 'bloc/complete_profile_cubit.dart';
import 'bloc/complete_profile_state.dart';
import 'profile_bloc.dart';

class CompleteProfileScreen extends StatelessWidget {
  final UserProfile user;

  const CompleteProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CompleteProfileCubit(sl(), user),
      child: const _CompleteProfileView(),
    );
  }
}

class _CompleteProfileView extends StatefulWidget {
  const _CompleteProfileView();

  @override
  State<_CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<_CompleteProfileView> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage(BuildContext context) {
    context.read<CompleteProfileCubit>().nextStep();
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _previousPage(BuildContext context) {
    context.read<CompleteProfileCubit>().previousStep();
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CompleteProfileCubit, CompleteProfileState>(
      listener: (context, state) {
        if (state.isSuccess) {
          // Profile completed. The ProfileCheckWrapper in main.dart will 
          // automatically switch to MainScaffold once it sees the 
          // isProfileComplete flag change in the Firestore stream.
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red));
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: Wumbleheme.backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: state.currentStep > 0
                    ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => _previousPage(context))
                    : null,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 25,
                      height: 4,
                      decoration: BoxDecoration(
                        color: state.currentStep >= index ? Wumbleheme.secondaryColor : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe, force buttons
                  children: [
                    _StepIdentity(onNext: () => _nextPage(context)),
                    _StepBirthday(onNext: () => _nextPage(context)),
                    _StepBio(onNext: () => _nextPage(context)),
                    _StepStyle(onNext: () => context.read<CompleteProfileCubit>().submitProfile()),
                  ],
                ),
              ),
            ),
            // Loading and Error Overlay
            if (state.isSubmitting || state.errorMessage != null)
              Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.errorMessage != null) ...[
                          const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.redAccent),
                          const SizedBox(height: 24),
                          const Text(
                            'ERROR DE CONEXIÓN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 48),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.read<CompleteProfileCubit>().clearError(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('CANCELAR'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => context.read<CompleteProfileCubit>().submitProfile(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Wumbleheme.secondaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: const Text('REINTENTAR', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const CircularProgressIndicator(
                            color: Wumbleheme.secondaryColor,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'ACTUALIZANDO... ${(state.uploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Estamos preparando todo para ti',
                            style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w300),
                          ),
                          const SizedBox(height: 40),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: state.uploadProgress,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation(Wumbleheme.secondaryColor),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StepIdentity extends StatefulWidget {
  final VoidCallback onNext;
  const _StepIdentity({required this.onNext});

  @override
  State<_StepIdentity> createState() => _StepIdentityState();
}

class _StepIdentityState extends State<_StepIdentity> {
  late TextEditingController _nameController;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    final state = context.read<CompleteProfileCubit>().state;
    _nameController = TextEditingController(text: state.displayName);
    _avatarFile = state.avatarFile;
  }

  Future<void> _pickImage() async {
    final picked = await MediaHelper.pickImageWithOptimization(context);
    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
      });
      if (mounted) {
        context.read<CompleteProfileCubit>().updateIdentity(_nameController.text, _avatarFile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Paso 1: Tu Identidad', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        const Text('¡Elige tu mejor ángulo y un nombre que te represente!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white10,
            backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
            child: _avatarFile == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white54) : null,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'Tu nombre o apodo',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Wumbleheme.secondaryColor)),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Wumbleheme.secondaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            onPressed: () {
              context.read<CompleteProfileCubit>().updateIdentity(_nameController.text, _avatarFile);
              widget.onNext();
            },
            child: const Text('SIGUIENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _StepBio extends StatefulWidget {
  final VoidCallback onNext;
  const _StepBio({required this.onNext});

  @override
  State<_StepBio> createState() => _StepBioState();
}

class _StepBioState extends State<_StepBio> {
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: context.read<CompleteProfileCubit>().state.bio);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Paso 2: Háblanos de ti', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        const Text('Las mejores amistades empiezan con un "Hola". ¿Qué te apasiona?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 40),
        TextField(
          controller: _bioController,
          style: const TextStyle(color: Colors.white),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Escribe algo genial aquí...',
            hintStyle: const TextStyle(color: Colors.white30),
            fillColor: Colors.white10,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Wumbleheme.secondaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            onPressed: () {
              context.read<CompleteProfileCubit>().updateBio(_bioController.text);
              widget.onNext();
            },
            child: const Text('SIGUIENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _StepStyle extends StatefulWidget {
  final VoidCallback onNext;
  const _StepStyle({required this.onNext});

  @override
  State<_StepStyle> createState() => _StepStyleState();
}

class _StepStyleState extends State<_StepStyle> {
  File? _bannerFile;
  File? _bgFile;

  Future<void> _pickImage(bool isBanner) async {
    final picked = await MediaHelper.pickImageWithOptimization(context);
    if (picked != null) {
      setState(() {
        if (isBanner) {
          _bannerFile = File(picked.path);
        } else {
          _bgFile = File(picked.path);
        }
      });
      if (mounted) {
        context.read<CompleteProfileCubit>().updateStyle(_bgFile, _bannerFile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<CompleteProfileCubit>().state.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Paso 3: Tu Estilo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        const Text('¡Dale color a tu muro! Haz que tu perfil sea 100% tú.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 40),
        
        // Custom Banner Picker
        GestureDetector(
          onTap: () => _pickImage(true),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              image: _bannerFile != null 
                ? DecorationImage(
                    image: FileImage(_bannerFile!), 
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
                  ) 
                : null,
            ),
            child: _bannerFile == null 
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_size_select_actual, color: Colors.white54, size: 30),
                    SizedBox(height: 8),
                    Text('Añadir Portada', style: TextStyle(color: Colors.white54)),
                  ],
                )
              : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit, color: Colors.white))),
          ),
        ),
        const SizedBox(height: 20),
        
        // Custom Background Picker
        GestureDetector(
          onTap: () => _pickImage(false),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              image: _bgFile != null 
                ? DecorationImage(
                    image: FileImage(_bgFile!), 
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
                  ) 
                : null,
            ),
             child: _bgFile == null 
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wallpaper, color: Colors.white54, size: 30),
                    SizedBox(height: 8),
                    Text('Fondo de Perfil', style: TextStyle(color: Colors.white54)),
                  ],
                )
              : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit, color: Colors.white))),
          ),
        ),
        
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Wumbleheme.secondaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            onPressed: isSubmitting ? null : widget.onNext,
            child: isSubmitting 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('¡EMPEZAR!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _StepBirthday extends StatefulWidget {
  final VoidCallback onNext;
  const _StepBirthday({required this.onNext});

  @override
  State<_StepBirthday> createState() => _StepBirthdayState();
}

class _StepBirthdayState extends State<_StepBirthday> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = context.read<CompleteProfileCubit>().state.birthday;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Paso 2: Tu Cumpleaños', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        const Text('¡Dinos cuándo celebrarte! Queremos enviarte confeti en tu día especial.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 40),
        
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              locale: const Locale('es', 'ES'),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Wumbleheme.secondaryColor,
                      onPrimary: Colors.white,
                      surface: Wumbleheme.surfaceColor,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
              if (mounted) {
                context.read<CompleteProfileCubit>().updateBirthday(picked);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _selectedDate != null ? Wumbleheme.secondaryColor : Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cake_outlined, color: _selectedDate != null ? Wumbleheme.secondaryColor : Colors.white30, size: 28),
                const SizedBox(width: 16),
                Text(
                  _selectedDate == null 
                      ? 'Seleccionar fecha' 
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.white30 : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Wumbleheme.secondaryColor, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              disabledBackgroundColor: Wumbleheme.secondaryColor.withOpacity(0.3),
            ),
            onPressed: _selectedDate == null ? null : widget.onNext,
            child: const Text('SIGUIENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
