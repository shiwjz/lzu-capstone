part of 'app_screens.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.app});
  final AppState app;
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String filter = '';
  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    title: '친구',
    subtitle: '친구들과 취향을 나누고 함께 떠나요',
    showBack: false,
    child: stackItems([
      OdigaSearchField(
        hint: '친구 이름으로 검색',
        onChanged: (v) => setState(() => filter = v),
      ),
      InkWell(
        onTap: () => openPage(context, GroupScreen(app: widget.app), '/group'),
        child: panel([
          label(widget.app.groupName, size: 18, bold: true),
          label(
            '${widget.app.userName} · ${widget.app.friends.map((f) => f.name).join(' · ')} / ${widget.app.friends.length + 1}명',
            size: 11,
            color: OdigaTokens.muted,
          ),
          label('모임방 열기 →', color: OdigaTokens.brand),
        ], lavender: true),
      ),
      label('내 친구 ${widget.app.friends.length}명', size: 18, bold: true),
      for (final f in widget.app.friends.where((f) => f.name.contains(filter)))
        FriendCard(
          name: f.name,
          initial: f.name.characters.first,
          status: f.status,
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(f.name),
              content: Text(
                '${f.status}\n${f.tags.map((t) => '#$t').join(' ')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      if (!widget.app.friends.any((f) => f.name.contains(filter)))
        label('검색된 친구가 없습니다.'),
      action('+ 친구 초대', () => _invite(context, widget.app), secondary: true),
      action('새 모임 만들기', () async {
        final name = await editText(context, '모임 이름', initial: '이번 주말 성수 모임');
        if (!context.mounted || name == null) return;
        widget.app.createGroup(name);
        openPage(context, GroupScreen(app: widget.app), '/group');
      }),
    ]),
  );
}

Future<void> _invite(BuildContext context, AppState app) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('함께 오디가?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(
          '초대 코드를 복사하거나 데모 친구를 추가해보세요.',
          size: 11,
          color: OdigaTokens.muted,
        ),
        const SizedBox(height: 16),
        panel([
          Center(
            child: label(
              'ODIGA-DEMO',
              size: 18,
              bold: true,
              color: OdigaTokens.brand,
            ),
          ),
        ], lavender: true),
        const SizedBox(height: 12),
        action('초대 코드 복사', () async {
          await Clipboard.setData(const ClipboardData(text: 'ODIGA-DEMO'));
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
            toast(context, '데모 초대 코드를 복사했습니다.');
          }
        }),
        const SizedBox(height: 8),
        action('친구의 초대 코드 입력', () async {
          Navigator.pop(dialogContext);
          final code = await editText(
            context,
            '데모 초대 코드',
            initial: 'ODIGA-DEMO',
          );
          if (!context.mounted || code == null) return;
          toast(
            context,
            app.addDemoFriend(code)
                ? '민수님을 예시 친구에 추가했습니다.'
                : '코드가 다르거나 이미 추가한 친구입니다.',
          );
        }, secondary: true),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('닫기'),
      ),
    ],
  ),
);

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: app,
    builder: (_, child) => AppFrame(
      app: app,
      title: app.groupName,
      subtitle: '${app.friends.length + 1}명이 함께 만드는 주말',
      child: stackItems([
        panel([
          label('참여자 ${app.friends.length + 1}명', bold: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OdigaAvatar(initial: app.userName.characters.first),
              ...app.friends.map(
                (f) => OdigaAvatar(initial: f.name.characters.first),
              ),
            ],
          ),
        ]),
        InkWell(
          onTap: () => openPage(
            context,
            ConditionsScreen(app: app, group: true),
            '/group/conditions',
          ),
          child: panel([
            label(
              '일정 선택 · ${dateText(app.conditions.start)} ${clockText(app.conditions.start)} ›',
              size: 18,
              bold: true,
            ),
            label(
              '${app.conditions.region} · ${app.friends.length + 1}명 · 식사 + 카페 + 산책',
              size: 11,
              color: OdigaTokens.muted,
            ),
            label('모임 조건과 취향을 반영해 추천해요', size: 11, color: OdigaTokens.brand),
          ], lavender: true),
        ),
        InkWell(
          onTap: () => openPage(context, ChatScreen(app: app), '/group/chat'),
          child: panel([
            label('최근 대화', bold: true),
            ...app.messages.reversed
                .take(3)
                .toList()
                .reversed
                .map((m) => label('${m.author}   ${m.text}')),
          ]),
        ),
        action('우리에게 맞는 코스 추천받기', () {
          app.setConditions(
            app.conditions.copy()
              ..people = (app.friends.length + 1).clamp(1, 12),
          );
          openPage(
            context,
            RecommendationsScreen(app: app, group: true),
            '/group/recommendations',
          );
        }),
        action(
          '우리 모임 선호도 보기',
          () => openPage(
            context,
            GroupPreferenceScreen(app: app),
            '/group/preferences',
          ),
          secondary: true,
        ),
        action(
          '채팅방 열기',
          () => openPage(context, ChatScreen(app: app), '/group/chat'),
          secondary: true,
        ),
      ]),
    ),
  );
}

class GroupPreferenceScreen extends StatelessWidget {
  const GroupPreferenceScreen({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final tags = [
      ...app.preference.categories,
      ...app.preference.moods,
      ...app.friends.expand((f) => f.tags),
    ];
    final unique = tags.toSet();
    return AppFrame(
      app: app,
      title: '우리 모임이 좋아하는 것',
      subtitle: '예시 친구들의 취향을 함께 모았어요',
      child: stackItems([
        panel([
          for (final tag in unique) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                label(tag),
                label(
                  '${tags.where((t) => t == tag).length}개 선호',
                  color: OdigaTokens.brand,
                ),
              ],
            ),
            LinearProgressIndicator(
              value:
                  (tags.where((t) => t == tag).length /
                          (app.friends.length + 1))
                      .clamp(0, 1),
              color: OdigaTokens.brand,
              backgroundColor: OdigaTokens.lavender,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
          ],
        ]),
        label('공통 선호', size: 18, bold: true),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: unique
              .map((t) => OdigaTag(label: '#$t', selected: true))
              .toList(),
        ),
        panel([
          label('✧ 모두의 취향을 균형 있게', color: OdigaTokens.brand),
          label('모임 구성원의 예시 취향과 이동거리를 함께 살펴보세요.'),
        ], lavender: true),
        action(
          '그룹 맞춤 코스 추천받기',
          () => openPage(
            context,
            RecommendationsScreen(app: app, group: true, expanded: true),
            '/group/recommendations',
          ),
        ),
      ]),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.app});
  final AppState app;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send() {
    if (input.text.trim().isEmpty) return;
    widget.app.sendMessage(input.text);
    input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.app,
    builder: (_, child) => AppFrame(
      app: widget.app,
      title: widget.app.groupName,
      subtitle: '참여자 ${widget.app.friends.length + 1}명 · 로컬 예시 채팅',
      scroll: false,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: widget.app.messages.length,
              separatorBuilder: (_, i) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final m = widget.app.messages[i];
                return panel([
                  label(
                    '${m.author} · ${clockText(m.sentAt)}',
                    size: 11,
                    color: OdigaTokens.muted,
                  ),
                  label(m.text),
                  if (m.course != null)
                    CourseCard(
                      title: m.course!.title,
                      route: m.course!.stops
                          .map(
                            (s) =>
                                widget.app.repository.place(s.placeId).category,
                          )
                          .join(' → '),
                      summary: summary(m.course!),
                      reason: '공유한 코스 · 자세히 보기 ›',
                      congestion: '예시 코스',
                      onTap: () => openPage(
                        context,
                        CourseDetailScreen(app: widget.app, initial: m.course!),
                        '/course/${m.course!.id}',
                      ),
                    ),
                ], lavender: m.author == widget.app.userName);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(onPressed: send, child: const Text('전송 ↑')),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => AppFrame(
    app: app,
    title: '마이',
    subtitle: '나를 알아갈수록 추천이 더 좋아져요',
    showBack: false,
    child: stackItems([
      panel([
        Row(
          children: [
            OdigaAvatar(initial: app.userName.characters.first),
            const SizedBox(width: 18),
            Expanded(
              child: stackItems([
                label(app.userName, size: 18, bold: true),
                label(
                  '${app.preference.moods.join(' · ')} 분위기를 좋아해요',
                  size: 11,
                  color: OdigaTokens.muted,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final name = await editText(
                        context,
                        '프로필 이름',
                        initial: app.userName,
                      );
                      if (name != null) app.rename(name);
                    },
                    child: const Text('프로필 편집 ›'),
                  ),
                ),
              ], gap: 3),
            ),
          ],
        ),
      ], lavender: true),
      _menu(
        '내 선호도 설정',
        () => openPage(context, PreferencesScreen(app: app), '/preferences'),
      ),
      _menu(
        '저장한 장소',
        () => openPage(context, SavedPlacesScreen(app: app), '/saved-places'),
      ),
      _menu('저장한 코스', () => rootTab(context, app, 1)),
      _menu('친구 관리', () => rootTab(context, app, 2)),
      _menu(
        '알레르기 / 필수 조건',
        () => openPage(context, PreferencesScreen(app: app), '/preferences'),
      ),
      _menu(
        '프로토타입 안내',
        () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오디가 프로토타입'),
            content: const Text(
              '지도·장소·혼잡도·추천은 예시입니다.\n저장과 채팅은 앱 실행 중에만 유지됩니다.\n실제 로그인, 카카오맵, AI, 서버는 연결 전입니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    ]),
  );
  Widget _menu(String text, VoidCallback onTap) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: ListTile(
      title: label(text),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      minTileHeight: 62,
    ),
  );
}

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.app});
  final AppState app;
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final draft = widget.app.preference.copy();
  late final allergies = TextEditingController(text: draft.allergies);
  late final disliked = TextEditingController(text: draft.dislikedFood);
  @override
  void dispose() {
    allergies.dispose();
    disliked.dispose();
    super.dispose();
  }

  Widget choices(List<String> options, Set<String> selected) => Wrap(
    spacing: 6,
    runSpacing: 8,
    children: options
        .map(
          (v) => OdigaTag(
            label: v,
            selected: selected.contains(v),
            onSelected: (value) => setState(() {
              if (value) {
                selected.add(v);
              } else {
                selected.remove(v);
              }
            }),
          ),
        )
        .toList(),
  );
  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    title: '내 취향을 알려주세요',
    subtitle: '추천에 반영할 관심사와 조건',
    child: stackItems([
      label('좋아하는 장소', size: 18, bold: true),
      choices(['음식점', '카페', '놀거리', '문화시설'], draft.categories),
      label('좋아하는 분위기', size: 18, bold: true),
      choices(['조용한', '활기찬', '감성적인', '사진', '데이트', '친구 모임'], draft.moods),
      panel([
        label('음식 취향', bold: true),
        TextField(
          controller: disliked,
          decoration: const InputDecoration(
            labelText: '싫어하는 음식',
            hintText: '예: 매운 음식',
          ),
        ),
      ]),
      panel([
        label('알레르기 / 필수 조건', color: OdigaTokens.brand),
        TextField(
          controller: allergies,
          decoration: const InputDecoration(
            labelText: '알레르기·필수 조건',
            hintText: '예: 견과류 알레르기',
          ),
        ),
        label(
          '현재는 조건 저장만 지원하며 음식 안전성은 판정하지 않습니다.',
          size: 11,
          color: OdigaTokens.muted,
        ),
      ], lavender: true),
      action('선호도 저장', () {
        draft.allergies = allergies.text.trim();
        draft.dislikedFood = disliked.text.trim();
        widget.app.setPreference(draft);
        Navigator.pop(context);
        toast(context, '선호도를 저장했습니다.');
      }),
    ]),
  );
}
