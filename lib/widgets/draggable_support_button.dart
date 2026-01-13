import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:url_launcher/url_launcher.dart';

class DraggableSupportButton extends StatefulWidget {
  const DraggableSupportButton({super.key});

  @override
  State<DraggableSupportButton> createState() => _DraggableSupportButtonState();
}

class _DraggableSupportButtonState extends State<DraggableSupportButton> {
  double _left = 0;
  double _top = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      // Start at bottom right with padding
      // Button size approx 56. Padding 16 from right, 100 from bottom (to avoid covering FABs or nav bars)
      _left = size.width - 72; // 56 + 16
      _top = size.height - 180; // Enough gap from bottom
      _initialized = true;
    }
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => const SupportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      child: GestureDetector(
        // onPanUpdate handles immediate dragging
        onPanUpdate: (details) {
          setState(() {
            _left += details.delta.dx;
            _top += details.delta.dy;
            
            // Constrain to screen boundaries with some padding
            final size = MediaQuery.of(context).size;
            _left = _left.clamp(0.0, size.width - 56.0);
            _top = _top.clamp(0.0, size.height - 56.0);
          });
        },
        child: FloatingActionButton(
          onPressed: _showSupportDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          // Remove shadow for smoother drag feel or keep it for depth? distinct depth is nice.
          elevation: 6,
          child: const Icon(Icons.support_agent),
        ),
      ),
    );
  }
}

class SupportDialog extends StatefulWidget {
  const SupportDialog({super.key});

  @override
  State<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<SupportDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final TextEditingController _smsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(String message) async {
    final urlString = 'https://wa.me/8801912336505?text=${Uri.encodeComponent(message)}';
    final url = Uri.parse(urlString);
    
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _smsController.text = data!.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 12, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Support'),
            TextButton.icon(
              onPressed: () => _launchWhatsApp("Asalamualaikum. Your Money Load Manager app is great!"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.waving_hand, size: 20),
              label: const Text('Say Hi'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Drop your SMS which you want to calculate using this app:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _smsController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste SMS content here...',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('Paste'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  if (_smsController.text.trim().isNotEmpty) {
                    _launchWhatsApp("Please calculate this SMS: \n" + _smsController.text.trim());
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Send SMS'),
                style: FilledButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
