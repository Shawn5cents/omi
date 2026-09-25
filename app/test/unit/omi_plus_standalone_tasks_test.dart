import 'package:flutter_test/flutter_test.dart';

import 'package:omi/providers/action_items_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('standalone tasks never call the Omi fetcher and mutate locally', () async {
    var fetchCalls = 0;
    final provider = ActionItemsProvider(
      getActionItems: ({
        int limit = 100,
        int offset = 0,
        bool? completed,
        String? conversationId,
        DateTime? startDate,
        DateTime? endDate,
        DateTime? dueStartDate,
        DateTime? dueEndDate,
      }) async {
        fetchCalls++;
        return null;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(fetchCalls, 0);

    final created = await provider.createActionItem(description: 'Standalone task');
    expect(created, isNotNull);
    expect(provider.actionItems, hasLength(1));

    final updated = await provider.updateActionItemState(created!, true);
    expect(updated, isTrue);
    expect(provider.actionItems.single.completed, isTrue);
    expect(fetchCalls, 0);

    final deleted = await provider.deleteActionItem(provider.actionItems.single);
    expect(deleted, isTrue);
    expect(provider.actionItems, isEmpty);
    expect(fetchCalls, 0);

    provider.dispose();
  });
}
