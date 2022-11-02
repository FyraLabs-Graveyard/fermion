sources = [
   'application.vala',
   'window.vala',
   'preferences.vala',
   'utils.vala',
   'widgets/terminal.vala',
   'handlers/keyboard.vala',
   'handlers/mouse.vala',
   'dialogs/unsafe_paste.vala',
   'dialogs/process.vala'
]

config_file = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf
)

glib_dep = dependency('glib-2.0')
linux_dep = meson.get_compiler('vala').find_library('linux', required: false)

if glib_dep.version().version_compare('>=2.73.2')
    add_project_arguments('--define', 'HAS_GLIB_2_74', language: 'vala')
endif

if linux_dep.found()
    add_project_arguments('--define', 'HAS_LINUX', language: 'vala')
endif

deps = [
    dependency('gtk4'),
    dependency('libhelium-1'),
    dependency('gee-0.8'),
    dependency('vte-2.91-gtk4', version: '>= 0.70'),
    dependency('libpcre2-8'),
    glib_dep,
    linux_dep,
    meson.get_compiler('vala').find_library('posix')
]

add_project_arguments(['--define', 'VTE_0_68_GTK4'], language : 'vala')

gnome = import('gnome')

executable(
    meson.project_name(),
	sources,
    config_file,
	asresources,
	vala_args: '--target-glib=2.50',
	dependencies: deps,
	install: true,
)
