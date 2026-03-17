import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/groups/groups_controller.dart';
import 'package:soundimplosion/app/features/groups/groups_repository.dart';

class GroupsPageMobile extends StatefulWidget {
  const GroupsPageMobile({
    super.key,
    this.embedded = false,
    this.initialGroupIdToOpen,
  });

  final bool embedded;
  final String? initialGroupIdToOpen;

  @override
  State<GroupsPageMobile> createState() => _GroupsPageMobileState();
}

class _GroupsPageMobileState extends State<GroupsPageMobile> {
  final GroupsController _controller = GroupsController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  final Map<String, TextEditingController> _inviteControllers = {};
  bool _didOpenInitialGroup = false;

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
    _groupDescriptionController.dispose();
    for (final controller in _inviteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_didOpenInitialGroup &&
        widget.initialGroupIdToOpen != null &&
        widget.initialGroupIdToOpen!.isNotEmpty &&
        _controller.groups.isNotEmpty) {
      final match = _controller.groups.where(
        (group) => group.id == widget.initialGroupIdToOpen,
      );
      if (match.isNotEmpty) {
        _didOpenInitialGroup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showGroupDetails(match.first);
          }
        });
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  TextEditingController _inviteControllerFor(String groupId) {
    return _inviteControllers.putIfAbsent(groupId, TextEditingController.new);
  }

  Future<void> _createGroup() async {
    try {
      await _controller.createGroup(
        _groupNameController.text,
        description: _groupDescriptionController.text,
      );
      _groupNameController.clear();
      _groupDescriptionController.clear();
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
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _removeMember(
    GroupListItem group,
    String targetUserId,
    String targetNickname,
  ) async {
    try {
      await _controller.removeUserFromGroup(
        groupId: group.id,
        targetUserId: targetUserId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$targetNickname rimosso dal gruppo ${group.name}'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _leaveGroup(GroupListItem group) async {
    try {
      await _controller.leaveGroup(group.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sei uscito dal gruppo ${group.name}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _deleteGroup(GroupListItem group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina gruppo'),
        content: Text(
          'Vuoi eliminare definitivamente il gruppo ${group.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.deleteGroup(group.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gruppo ${group.name} eliminato')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _showGroupDetails(GroupListItem group) async {
    final currentUserId = _controller.currentUserId;
    final isOwner = group.isOwnedBy(currentUserId);
    final canManageMembers = isOwner || _controller.isAdmin;
    final canDeleteGroup = isOwner || _controller.isAdmin;
    final canLeaveGroup =
        currentUserId != null && currentUserId != group.ownerId;
    final inviteController = _inviteControllerFor(group.id);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(group.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Descrizione',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  group.description.isEmpty
                      ? 'Nessuna descrizione disponibile.'
                      : group.description,
                ),
                const SizedBox(height: 16),
                Text(
                  'Numero utenti: ${group.memberCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Utenti',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: group.sortedMembers.length,
                    itemBuilder: (context, index) {
                      final member = group.sortedMembers[index];
                      final memberId = member.key;
                      final memberNickname = member.value;
                      final isMemberOwner = memberId == group.ownerId;
                      final canRemoveMember =
                          canManageMembers && !isMemberOwner;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            memberNickname.isNotEmpty
                                ? memberNickname[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(memberNickname),
                        subtitle: Text(
                          isMemberOwner ? 'Proprietario' : memberId,
                        ),
                        trailing: canRemoveMember
                            ? IconButton(
                                onPressed: _controller.isSubmitting
                                    ? null
                                    : () => _removeMember(
                                        group,
                                        memberId,
                                        memberNickname,
                                      ),
                                icon: const Icon(
                                  Icons.person_remove,
                                  color: Colors.red,
                                ),
                                tooltip: 'Rimuovi utente',
                              )
                            : null,
                      );
                    },
                  ),
                ),
                if (canManageMembers) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: inviteController,
                    decoration: const InputDecoration(
                      labelText: 'Invita tramite username',
                      hintText: 'Inserisci lo username esatto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_add),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _inviteToGroup(group),
                      child: const Text('Invita membro'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (canDeleteGroup)
            TextButton(
              onPressed: _controller.isSubmitting
                  ? null
                  : () => _deleteGroup(group),
              child: const Text(
                'Elimina gruppo',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (canLeaveGroup)
            TextButton(
              onPressed: _controller.isSubmitting
                  ? null
                  : () => _leaveGroup(group),
              child: const Text('Esci dal gruppo'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteToGroup(GroupListItem group) async {
    final inviteController = _inviteControllerFor(group.id);
    try {
      await _controller.inviteUserToGroup(
        groupId: group.id,
        nickname: inviteController.text,
      );
      inviteController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invito inviato al gruppo ${group.name}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
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
              TextField(
                controller: _groupDescriptionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrizione gruppo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
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
                return Center(
                  child: Text(
                    'Errore caricamento gruppi: ${_controller.error}',
                  ),
                );
              }

              if (_controller.groups.isEmpty) {
                return const Center(
                  child: Text('Non fai ancora parte di nessun gruppo.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _controller.groups.length,
                itemBuilder: (context, index) {
                  final group = _controller.groups[index];
                  final isOwner = group.isOwnedBy(_controller.currentUserId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showGroupDetails(group),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
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
                            Text(
                              group.description.isEmpty
                                  ? 'Nessuna descrizione disponibile.'
                                  : group.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text('Utenti: ${group.memberCount}'),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showGroupDetails(group),
                                icon: const Icon(Icons.info_outline),
                                label: const Text('Dettagli gruppo'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gruppi')),
      body: body,
    );
  }
}
