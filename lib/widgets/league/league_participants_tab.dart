import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class LeagueParticipantsTab extends StatelessWidget {
  final List<String> participants;
  final VoidCallback onAddParticipant;
  final ValueChanged<String> onRemoveParticipant;

  const LeagueParticipantsTab({
    super.key,
    required this.participants,
    required this.onAddParticipant,
    required this.onRemoveParticipant,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: participants.isEmpty ? 3 : participants.length + 2,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${participants.length} PARTICIPANTES REGISTRADOS',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate400),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onAddParticipant,
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('Agregar', style: TextStyle(fontSize: 12)),
              ),
            ],
          );
        }
        if (i == 1) return const SizedBox(height: 8);

        if (participants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No hay participantes en la liga. Agrega jugadores para armar las partidas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
          );
        }

        final participant = participants[i - 2];
        return Container(
          key: ValueKey('participant_$participant'),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.slate800,
                      child: Icon(Icons.person,
                          size: 16, color: AppColors.slate300),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        participant,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 16, color: AppColors.slate500),
                onPressed: () => onRemoveParticipant(participant),
              ),
            ],
          ),
        );
      },
    );
  }
}
