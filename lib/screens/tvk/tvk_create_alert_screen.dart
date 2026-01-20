import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_alert.dart';
import '../../models/tvk/tvk_zone.dart';
import '../../services/location_service.dart';
import '../../widgets/tvk/tvk_theme.dart';

/// Screen for creating new alerts
class TVKCreateAlertScreen extends StatefulWidget {
  const TVKCreateAlertScreen({super.key});

  @override
  State<TVKCreateAlertScreen> createState() => _TVKCreateAlertScreenState();
}

class _TVKCreateAlertScreenState extends State<TVKCreateAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TVKAlertType _selectedType = TVKAlertType.general;
  TVKAlertSeverity _selectedSeverity = TVKAlertSeverity.medium;
  TVKZone? _selectedZone;
  Position? _currentPosition;
  bool _isCreating = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TVKTheme.themeData,
      child: Consumer<TVKEventProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: TVKColors.background,
            appBar: AppBar(
              backgroundColor: TVKColors.zoneDanger,
              title: const Text('Report Alert'),
            ),
            body: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alert type selection
                    _buildTypeSelector(),
                    const SizedBox(height: 24),

                    // Severity selection
                    _buildSeveritySelector(),
                    const SizedBox(height: 24),

                    // Title
                    _buildTitleField(),
                    const SizedBox(height: 16),

                    // Description
                    _buildDescriptionField(),
                    const SizedBox(height: 24),

                    // Zone selection
                    _buildZoneSelector(provider),
                    const SizedBox(height: 24),

                    // Location
                    _buildLocationCard(),
                    const SizedBox(height: 32),

                    // Submit button
                    _buildSubmitButton(provider),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alert Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TVKColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TVKAlertType.values.map((type) {
            final isSelected = _selectedType == type;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type.icon,
                    size: 16,
                    color: isSelected ? Colors.white : TVKColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(type.displayName),
                ],
              ),
              selected: isSelected,
              selectedColor: TVKColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : TVKColors.textPrimary,
              ),
              onSelected: (_) => setState(() => _selectedType = type),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSeveritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Severity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TVKColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: TVKAlertSeverity.values.map((severity) {
            final isSelected = _selectedSeverity == severity;
            final color = TVKTheme.getAlertSeverityColor(severity.value);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: severity != TVKAlertSeverity.critical ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSeverity = severity),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          severity.displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : TVKColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Title',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TVKColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Brief description of the issue',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TVKColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Provide more details about the situation',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildZoneSelector(TVKEventProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Zone (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TVKColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<TVKZone?>(
            value: _selectedZone,
            decoration: InputDecoration(
              hintText: 'Select zone',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            items: [
              const DropdownMenuItem<TVKZone?>(
                value: null,
                child: Text('No specific zone'),
              ),
              ...provider.zones.map((zone) {
                return DropdownMenuItem<TVKZone?>(
                  value: zone,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: TVKTheme.getZoneStatusColor(zone.status.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(zone.name),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedZone = value),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: TVKColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TVKColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_isLoadingLocation)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TVKColors.primary,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: TVKColors.primary),
                    onPressed: _loadLocation,
                    tooltip: 'Refresh location',
                  ),
              ],
            ),
            const Divider(height: 24),
            if (_currentPosition != null)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current coordinates',
                          style: TextStyle(
                            color: TVKColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: TVKColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: TVKColors.zoneSafe.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 14, color: TVKColors.zoneSafe),
                        const SizedBox(width: 4),
                        Text(
                          '±${_currentPosition!.accuracy.toInt()}m',
                          style: const TextStyle(
                            color: TVKColors.zoneSafe,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Unable to get location. Please enable location services.',
                style: TextStyle(color: TVKColors.zoneDanger),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(TVKEventProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCreating || _currentPosition == null
            ? null
            : () => _submitAlert(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: TVKColors.zoneDanger,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: _isCreating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'REPORT ALERT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Future<void> _submitAlert(TVKEventProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get location'),
          backgroundColor: TVKColors.zoneDanger,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final alertId = await provider.createAlert(
        type: _selectedType,
        severity: _selectedSeverity,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        zoneId: _selectedZone?.id,
        zoneName: _selectedZone?.name,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      if (alertId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert reported successfully'),
            backgroundColor: TVKColors.zoneSafe,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create alert'),
            backgroundColor: TVKColors.zoneDanger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: TVKColors.zoneDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}
