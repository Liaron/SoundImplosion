import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/groups/groups_controller.dart';
import 'package:soundimplosion/app/features/groups/groups_repository.dart';

class GroupsPageMobile extends StatefulWidget {
  const GroupsPageMobile({super.key});

  @override
  State<GroupsPageMobile> createState() => _GroupsPageMobileState();
}

class _GroupsPageMobileState extends State<GroupsPageMobile> {
  final GroupsController _controller = GroupsController();
  final TextEditingController _groupNameController = TextEditingController();
  final Map<String, TextEditingController> _inviteControllers = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _groupNameController.dispose();
    for (final controller in _inviteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  TextEditingController _inviteControllerFor(String groupId) {
    return _inviteControllers.putIfAbsent(groupId, TextEditingController.new);
  }

  Future<void> _createGroup() async {
    try {
      await _controller.createGroup(_groupNameController.text);
      _groupNameController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gruppo creato correttamente')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  Future<void> _inviteToGroup(GroupListItem group) async {
    final inviteController = _inviteControllerFor(group.id);
    try {
      await _controller.inviteUserToGroup(groupId: group.id, nickname: inviteController.text);
      inviteController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Utente aggiunto al gruppo ${group.name}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gruppi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome nuovo gruppo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group_add),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _controller.isSubmitting ? null : _createGroup,
                  child: const Text('Crea gruppo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_controller.error != null) {
                  return Center(child: Text('Errore caricamento gruppi: ${_controller.error}'));
                }

                if (_controller.groups.isEmpty) {
                  return const Center(child: Text('Non fai ancora parte di nessun gruppo.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _controller.groups.length,
                  itemBuilder: (context, index) {
                    final group = _controller.groups[index];
                    final isOwner = group.isOwnedBy(_controller.currentUserId);
                    final canManageMembers = isOwner || _controller.isAdmin;
                    final inviteController = _inviteControllerFor(group.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    isOwner
                                        ? 'Proprietario'
                                        : _controller.isAdmin
                                        ? 'Admin'
                                        : 'Membro',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Membri: ${group.memberNames.join(', ')}'),
                            if (canManageMembers) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: inviteController,
                                decoration: const InputDecoration(
                                  labelText: 'Invita tramite username',
                                  hintText: 'Inserisci il nickname esatto',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_add),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: _controller.isSubmitting ? null : () => _inviteToGroup(group),
                                  child: const Text('Invita membro'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}