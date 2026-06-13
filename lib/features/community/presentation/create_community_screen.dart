import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme.dart';
import '../domain/community_model.dart';
import '../../../../core/utils/media_helper.dart';
import 'bloc/community_bloc.dart';
import 'community_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Data
  String _name = '';
  String _handle = ''; // e.g. /c/mycommunity
  String _description = '';
  CommunityPrivacy _privacy = CommunityPrivacy.open; // Updated enum name
  Color _themeColor = Colors.blue;
  String _category = 'General';
  List<String> _tags = []; // NEW
  final TextEditingController _tagsController = TextEditingController(); // NEW
  final TextEditingController _customCategoryController = TextEditingController(); // NEW
  
  final List<String> _categories = [...Community.categories, 'Otro...'];
  
  // Validation
  final _step1Key = GlobalKey<FormState>();

  // Images
  File? _iconFile;
  File? _bannerFile;
  File? _backgroundFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String type) async {
    // 70% quality and max size to support 3G connections
    final XFile? image = await MediaHelper.pickImageWithOptimization(context);
    if (image != null) {
      final file = File(image.path);
      final sizeMb = await file.length() / (1024 * 1024);
      print('DEBUG: UI - Image picked: $type, Size: ${sizeMb.toStringAsFixed(2)}MB');
      
      setState(() {
        if (type == 'banner') {
          _bannerFile = file;
        } else if (type == 'icon') {
          _iconFile = file;
        } else if (type == 'background') {
          _backgroundFile = file;
        }
      });
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color Personalizado', style: TextStyle(color: Colors.white)),
        backgroundColor: Wumbleheme.surfaceColor,
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _themeColor,
            onColorChanged: (color) => setState(() => _themeColor = color),
            paletteType: PaletteType.hsvWithHue,
            displayThumbColor: true,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ... (previous code structure remains similar, adding BlocListener)

  Widget _buildStep3Branding() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text('Estilo Visual', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                const Text('Define la identidad visual de tu comunidad.', style: TextStyle(color: Wumbleheme.textSecondary)),
                const SizedBox(height: 30),
                
                // Color Picker Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Color Tema', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _showColorPicker,
                      icon: const Icon(Icons.colorize, size: 16),
                      label: const Text('Personalizar'),
                      style: TextButton.styleFrom(foregroundColor: _themeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 45,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                        Colors.blue, Colors.red, Colors.green, Colors.purple, 
                        Colors.orange, Colors.pink, Colors.teal, Colors.indigo,
                        Colors.amber, Colors.cyan, Colors.lime, Colors.deepPurple
                    ].map((color) => GestureDetector(
                        onTap: () => setState(() => _themeColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(
                               color: _themeColor == color ? Colors.white : Colors.transparent,
                               width: 2,
                             ),
                          ),
                          child: CircleAvatar(
                              backgroundColor: color,
                              radius: 18,
                              child: _themeColor == color ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                          ),
                        ),
                    )).toList(),
                  ),
                ),
                
                const SizedBox(height: 35),
                
                // Icon Picker
                const Text('Icono de Comunidad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Text('Imagen cuadrada representativa', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _pickImage('icon'),
                  child: Container(
                    height: 120, 
                    width: 120,
                    decoration: BoxDecoration(
                      color: Wumbleheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10, width: 2),
                      image: _iconFile != null 
                          ? DecorationImage(image: FileImage(_iconFile!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _iconFile == null 
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 32, color: Colors.white54),
                              SizedBox(height: 4),
                              Text('Subir Icono', style: TextStyle(color: Colors.white24, fontSize: 10)),
                            ],
                          )
                        : null,
                  ),
                ),
                
                const SizedBox(height: 35),

                // Images Grid for Banner and Background
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Picker
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Banner de Comunidad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Text('Imagen vertical para listados.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _pickImage('banner'),
                            child: Container(
                              height: 180, 
                              decoration: BoxDecoration(
                                color: Wumbleheme.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10, width: 2),
                                image: _bannerFile != null 
                                    ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _bannerFile == null 
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.white54),
                                        SizedBox(height: 8),
                                        Text('Subir Banner', style: TextStyle(color: Colors.white24, fontSize: 10)),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Background Picker
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fondo Inmersivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Text('Imagen desenfocada de fondo.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _pickImage('background'),
                            child: Container(
                              height: 180, 
                              decoration: BoxDecoration(
                                color: Wumbleheme.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10, width: 2),
                                image: _backgroundFile != null 
                                    ? DecorationImage(image: FileImage(_backgroundFile!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _backgroundFile == null 
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, size: 36, color: Colors.white54),
                                        SizedBox(height: 8),
                                        Text('Subir Fondo', style: TextStyle(color: Colors.white24, fontSize: 10)),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
        ),
    );
  }
  
  bool _acceptedRules = false;

  void _nextPage() {
    if (_currentStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
      _step1Key.currentState!.save();
    }
    
    // Validate Rules acceptance at step 3 (0-indexed)
    if (_currentStep == 3 && !_acceptedRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar las normas para continuar.')),
      );
      return;
    }
    
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _createCommunity();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  void _createCommunity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Debes iniciar sesión para crear una comunidad.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final userId = user.uid;
    final communityId = const Uuid().v4();
    print('DEBUG: UI - Initiating creation for $communityId by $userId');

    final community = Community(
      id: communityId,
      name: _name,
      description: _description,
      handle: _handle,
      creatorId: userId,
      membersCount: 1,
      iconUrl: '', // Will be updated by repository
      bannerUrl: '', // Will be updated by repository
      backgroundUrl: '', // Will be updated by repository
      themeColorValue: _themeColor.value,
      category: () {
        if (_category != 'Otro...') return _category;
        final manual = _customCategoryController.text.trim();
        // Intelligent cleanup: Use official version if user typed a known one
        final officialMatch = Community.categories.firstWhere(
          (c) => c.toLowerCase() == manual.toLowerCase(),
          orElse: () => manual,
        );
        return officialMatch.isNotEmpty ? officialMatch : 'General';
      }(),
      privacy: _privacy.name,
      createdAt: DateTime.now(),
      tags: _tags, // NEW
    );

    context.read<CommunityBloc>().add(CreateCommunity(
      community: community,
      icon: _iconFile,
      banner: _bannerFile,
      background: _backgroundFile,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommunityBloc, CommunityState>(
      listener: (context, state) {
        if (state is CommunityCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Comunidad creada con éxito! 🎉')),
          );
          // Navigate to the community screen and replace the wizard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailScreen(community: state.community, isNewlyCreated: true),
            ),
          );
        } else if (state is CommunityError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Paso ${_currentStep + 1} de 5'),
          backgroundColor: Wumbleheme.backgroundColor,
          elevation: 0,
          leading: _currentStep > 0 
              ? IconButton(onPressed: _prevPage, icon: const Icon(Icons.arrow_back))
              : null,
        ),
        body: BlocBuilder<CommunityBloc, CommunityState>(
          builder: (context, state) {
            return Stack(
              children: [
                Column(
                  children: [
                    // Progress Bar
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / 5,
                      backgroundColor: Colors.white10,
                      color: _themeColor,
                    ),
                    
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStep1Identity(),
                          _buildStep2Privacy(),
                          _buildStep3Branding(),
                          _buildStep4Rules(),
                          _buildStep5Review(),
                        ],
                      ),
                    ),
                    
                    // Next Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (state is CommunityCreating) ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themeColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            _currentStep == 4 ? 'Crear Comunidad' : 'Siguiente',
                            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Premium Loading Overlay
                if (state is CommunityCreating) 
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  strokeWidth: 6,
                                  color: Wumbleheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                'Creando tu Wumble...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Estamos estableciendo los protocolos de tu comunidad.',
                                style: TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- STEPS ---

  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dale nombre a tu mundo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            const Text('Esto es lo primero que verán los miembros.', style: TextStyle(color: Wumbleheme.textSecondary)),
            const SizedBox(height: 30),
            
            TextFormField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre de la Comunidad', prefixIcon: Icon(Icons.group, color: Colors.white70)),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => _name = v!,
              onChanged: (v) => setState(() => _name = v),
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'URL (Handle)', prefixText: 'Wumble.app/c/', prefixIcon: Icon(Icons.link, color: Colors.white70)),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => _handle = v!,
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción Corta', alignLabelWithHint: true, prefixIcon: Icon(Icons.description, color: Colors.white70)),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => _description = v!,
            ),
            const SizedBox(height: 20),

             DropdownButtonFormField<String>(
              value: _category,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setState(() => _category = v!),
              dropdownColor: Wumbleheme.surfaceColor,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category, color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            
            if (_category == 'Otro...') ...[
              const SizedBox(height: 15),
              TextFormField(
                controller: _customCategoryController,
                style: const TextStyle(color: Colors.white70),
                decoration: const InputDecoration(
                  labelText: 'Escribe tu categoría personalizada',
                  hintText: 'ej: Astrobiología, Fandom Específico...',
                  prefixIcon: Icon(Icons.edit_note, color: Colors.blueAccent),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
                validator: (v) => (_category == 'Otro...' && (v == null || v.isEmpty)) ? 'Requerido' : null,
              ),
            ],
            
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _tagsController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Etiquetas de búsqueda (separadas por comas)',
                hintText: 'ej: gaming, rpg, español',
                prefixIcon: Icon(Icons.tag, color: Colors.white70),
                helperText: 'Ayuda a que otros encuentren tu comunidad.',
                helperStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: (v) {
                setState(() {
                  _tags = v.split(',')
                    .map((t) => t.trim().toLowerCase()) // Normalized
                    .where((t) => t.isNotEmpty)
                    .toSet() // Remove duplicates
                    .toList();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Privacy() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text('Privacidad', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            const Text('¿Quién puede unirse?', style: TextStyle(color: Wumbleheme.textSecondary)),
            const SizedBox(height: 30),
            
            _buildPrivacyOption(
                title: 'Abierta', 
                subtitle: 'Cualquiera puede entrar.', 
                icon: Icons.public,
                value: CommunityPrivacy.open
            ),
            _buildPrivacyOption(
                title: 'Requiere Aprobación', 
                subtitle: 'Debes aceptar las solicitudes.', 
                icon: Icons.approval,
                value: CommunityPrivacy.approval
            ),
            _buildPrivacyOption(
                title: 'Privada', 
                subtitle: 'Solo con invitación.', 
                icon: Icons.lock,
                value: CommunityPrivacy.private
            ),
        ],
      ),
    );
  }
  
  Widget _buildPrivacyOption({required String title, required String subtitle, required IconData icon, required CommunityPrivacy value}) {
      final isSelected = _privacy == value;
      return GestureDetector(
          onTap: () => setState(() => _privacy = value),
          child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: isSelected ? _themeColor.withOpacity(0.2) : Wumbleheme.surfaceColor,
                  border: Border.all(color: isSelected ? _themeColor : Colors.white10),
                  borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                  children: [
                      Icon(icon, size: 30, color: isSelected ? _themeColor : Colors.white54),
                      const SizedBox(width: 15),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white70)),
                                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white38)),
                              ],
                          ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: _themeColor),
                  ],
              ),
          ),
      );
  }


  Widget _buildStep4Rules() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Normas y Condiciones', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          const Text('Para mantener un ambiente seguro, todos los Agentes deben aceptar estas reglas:', style: TextStyle(color: Wumbleheme.textSecondary)),
          const SizedBox(height: 30),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Wumbleheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RuleItem(icon: Icons.favorite, title: 'Sé Respetuoso', description: 'Trata a todos los miembros con amabilidad y respeto.'),
                    SizedBox(height: 20),
                    _RuleItem(icon: Icons.no_adult_content, title: 'Contenido Apropiado', description: 'Prohibido el contenido +18, gore o violencia explícita.'),
                    SizedBox(height: 20),
                    _RuleItem(icon: Icons.security, title: 'Seguridad', description: 'No compartas información personal sensible ni permitas doxing.'),
                    SizedBox(height: 20),
                    _RuleItem(icon: Icons.copyright, title: 'Derechos de Autor', description: 'Respeta la propiedad intelectual de otros autores.'),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: () => setState(() => _acceptedRules = !_acceptedRules),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _acceptedRules ? _themeColor.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _acceptedRules ? _themeColor : Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(
                    _acceptedRules ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _acceptedRules ? _themeColor : Colors.white54,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'He leído y acepto cumplir con las Normas de Wumble.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Review() {
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent),
                  const SizedBox(height: 20),
                  const Text('¡Todo listo!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text('Estás a punto de crear "$_name".\nAl hacerlo, aceptas los Términos de Servicio de Wumble y asumes el rol de Agente.', 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Wumbleheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                          children: [
                              _ReviewRow(label: 'Nombre', value: _name),
                              _ReviewRow(label: 'URL', value: 'Wumble.app/c/$_handle'),
                              _ReviewRow(
                                label: 'Privacidad', 
                                value: _privacy == CommunityPrivacy.open 
                                  ? 'ABIERTA' 
                                  : _privacy == CommunityPrivacy.approval 
                                    ? 'REQUIERE APROBACIÓN' 
                                    : 'PRIVADA'
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (_iconFile != null) 
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(_iconFile!, width: 50, height: 50, fit: BoxFit.cover),
                                    ),
                                  if (_bannerFile != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(_bannerFile!, width: 40, height: 60, fit: BoxFit.cover),
                                    ),
                                  if (_backgroundFile != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(_backgroundFile!, width: 40, height: 60, fit: BoxFit.cover),
                                    ),
                                ],
                              )
                          ],
                      ),
                  ),
              ],
          ),
      );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _RuleItem({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
    final String label;
    final String value;
    const _ReviewRow({required this.label, required this.value});
    
    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(label, style: const TextStyle(color: Colors.white54)),
                    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
            ),
        );
    }
}
