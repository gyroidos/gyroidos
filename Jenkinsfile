def doCleanup() {
	if (params.SKIP_WS_CLEANUP) {
		echo "Skipping workspace cleanup on ${env.NODE_NAME} as requested"
	} else {
		echo "Cleaning workspace on ${env.NODE_NAME}"
		cleanWs cleanWhenAborted: true, cleanWhenFailure: true,
				cleanWhenNotBuilt: true, cleanWhenUnstable: true,
				notFailBuild: true
	}
}

def defineDockerImage() {
	def builduser = sh(script: 'id -u', returnStdout: true).trim()
	def kvmgid = sh(script: 'getent group kvm | cut -d: -f3', returnStdout: true).trim()
	return [
		image: docker.build("debian_jenkins_${builduser}_${kvmgid}", "--build-arg=BUILDUSER=${builduser} --build-arg=KVM_GID=${kvmgid} ${WORKSPACE}/.manifests"),
		builduser: builduser,
		kvmgid: kvmgid,
	]
}

properties([
	parameters([
		string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'ef371d61-2ed1-495d-93c4-792445b2d1bb', description: 'Jenkins credentials ID for GitHub authentication (usernamePassword type with PAT)'),
		string(name: 'CI_LIB_VERSION', defaultValue: 'main', description: 'Version of the gyroidos_ci_common library to be used (e.g. main or pull/<pr_num>/merge)'),
		booleanParam(name: 'RELEASE_BUILD', defaultValue: false, description: 'If true, only build release images and skip tasks required for PR builds'),
		string(name: 'LABEL_BUILDER', defaultValue: 'worker', description: 'Builder preference'),
		string(name: 'LABEL_TESTER', defaultValue: 'tester', description: 'Tester preference'),
		string(name: 'LABEL_TOKENTEST', defaultValue: 'tokentest', description: 'Token test node preference'),
		choice(name: 'GYROID_ARCH', choices: ['x86', 'arm32', 'arm64', 'riscv'], description: 'GyroidOS Target Architecture'),
		choice(name: 'GYROID_MACHINE', choices: ['genericx86-64', 'apalis-imx8', 'raspberrypi2', 'raspberrypi3-64', 'raspberrypi4-64', 'raspberrypi5', 'tqma8mpxl', 'tqmlx2160a', 'ls1088ardb-pb', 'beaglev-fire'], description: 'GyroidOS Target Machine (Must be compatible with GYROID_ARCH!)'),
		string(name: 'PR_BRANCHES', defaultValue: '', description: 'Comma separated list of pull request branches (e.g. meta-gyroidos=PR-177,meta-gyroidos-nxp=PR-13,gyroidos_build=PR-97)'),
		choice(name: 'BUILD_INSTALLER', choices: ['n', 'y'], description: 'Build the GyroidOS installer (x86 only)'),
		choice(name: 'CI_CONSOLE_REDIRECT', choices: ['y', 'n'], description: 'Redirect kernel/cml console to the CI serial backend for log capture. Set to n to build a hardware-deployable image.'),
		choice(name: 'START_FROM_STAGE', choices: ['Source checks + unit tests', 'Build Images', 'Integration Tests'], description: 'Stage to start from. Earlier stages will be skipped. When skipping "Build Images", BUILDSELECTOR must point to a build with existing artifacts.'),
		choice(name: 'REBUILD_PREVIOUS', choices: ['n', 'y'], description: 'Rebuild selected, previous build instead of just reusing image from artifacts'),
		buildSelector(defaultSelector: specific('${BUILD_NUMBER}'), name: 'BUILDSELECTOR', description: 'Image to perform integration tests on. Changing the default value skips the image build.'),
		choice(name: 'SYNC_MIRRORS', choices: ['n', 'y'], description: 'Sync source mirrors after successful build'),
		booleanParam(name: 'SKIP_WS_CLEANUP', defaultValue: false, description: 'If true, workspace cleanup after build will be skipped'),
		string(name: 'PKI_PATH', defaultValue: '', description: 'PKI path'),
		password(name: 'PKI_PASSWORD', defaultValue: '', description: 'PKI password'),
		booleanParam(name: 'SET_KEEP_FOREVER', defaultValue: false, description: 'Set "Keep this build forever"'),
		string(name: 'SET_DISPLAY_NAME', defaultValue: "", description: 'Set display name'),
	]),
	copyArtifactPermission('/GyroidOS_Pipelines/**'),
])

env.YOCTO_VERSION = 'scarthgap'

def stageOrder = ['Source checks + unit tests', 'Build Images', 'Integration Tests']
def startIdx = stageOrder.indexOf(params.START_FROM_STAGE ?: stageOrder[0])

if (startIdx > 0) {
	echo "Skipping to stage '${params.START_FROM_STAGE}'"
}

library identifier: "gyroidos_ci_common@${params.CI_LIB_VERSION ?: 'main'}", retriever: modernSCM(
	[$class: 'GitSCMSource', remote: "https://github.com/gyroidos/gyroidos_ci_common", credentialsId: params.GITHUB_CREDENTIALS_ID])

stage('Source checks + unit tests') {
if (startIdx > 0) {
	echo "Stage skipped (starting from '${params.START_FROM_STAGE}')"
} else {
	node(params.LABEL_TESTER ?: 'tester') {
		timeout(time: 30, unit: 'MINUTES') {
		try {
			dir('.manifests') {
				checkout scm
			}

			if (params.SET_KEEP_FOREVER) {
				echo "Keeping this build forever"
				currentBuild.setKeepLog(true)
			} else {
				echo "Leaving currentBuild.keepLog as is: ${currentBuild.keepLog}"
			}

			if ("" != params.SET_DISPLAY_NAME) {
				echo "Setting name to ${params.SET_DISPLAY_NAME}"
				currentBuild.displayName = params.SET_DISPLAY_NAME
			} else {
				echo "Leaving currentBuild.displayName as is: ${currentBuild.displayName}"
			}

			def docker_env = defineDockerImage()
			docker_env.image.inside("--user ${docker_env.builduser} --env NODE_NAME=${NODE_NAME}") {
				stepInitWs(workspace: "${WORKSPACE}",
					manifest_path: "${WORKSPACE}/.manifests",
					manifest_name: "yocto-${params.GYROID_ARCH}-${params.GYROID_MACHINE}.xml",
					gyroid_arch: params.GYROID_ARCH,
					gyroid_machine: params.GYROID_MACHINE,
					selector: buildParameter('BUILDSELECTOR'),
					rebuild_previous: "${params.REBUILD_PREVIOUS}",
					buildtype: "dev",
					pr_branches: params.PR_BRANCHES,
					github_credentials_id: params.GITHUB_CREDENTIALS_ID)
			}

			// Source tests
			if (params.RELEASE_BUILD) {
				echo "Skipping source tests during release build"
			} else if (!fileExists("gyroidos/cml")) {
				echo "CML sources not available, skipping initial tests"
			} else {
				echo "CML sources available, performing initial tests"
				// Static Code Analysis is performed using Semmle outside of this pipeline.
			// Check GitHub's project page for results.

			parallel(
					'Code Format & Style': {
						docker_env.image.inside("--user ${docker_env.builduser} --env NODE_NAME=${NODE_NAME}") {
							stepFormatCheck(workspace: WORKSPACE,
								sourcedir: "${WORKSPACE}/gyroidos/cml")
						}
					},
					'Unit tests': {
						docker_env.image.inside("--user ${docker_env.builduser} --env NODE_NAME=${NODE_NAME}") {
							stepUnitTests(workspace: WORKSPACE,
								sourcedir: "${WORKSPACE}/gyroidos/cml")
						}
					}
				)
			}
		} finally {
			doCleanup()
		}
		} // timeout
	} // node
} // if startIdx
} // stage('Source checks + unit tests')


stage('Build & Test') {
	def buildTypes = ['asan', 'ccmode', 'dev', 'production', 'hwhsm']
	def testModes = [asan: 'dev']
	// Extra VM-container-tests.sh flags per buildtype. The dev image runs its
	// test suite with signedcontainer1 as a softhsm2-backed PKCS#11 token.
	def extraOpts = [dev: '--test-pkcs11 libsofthsm2.so']
	def hsmEnvs = [
		schsm: { -> [serial: env.SCHSM_SERIAL, vid: env.SCHSM_VID, pid: env.SCHSM_PID, pin: env.PHYSHSM_PIN] },
		bnse:  { -> [serial: env.BNSE_SERIAL,  vid: env.BNSE_VID,  pid: env.BNSE_PID,  pin: env.PHYSHSM_PIN] },
	]
	def branches = [:]
	def completedBuilds = java.util.Collections.synchronizedMap(new java.util.HashMap())

	def activeBuildTypes = buildTypes.findAll { bt ->
		!(params.RELEASE_BUILD && bt != "dev" && bt != "production")
	}

	// Spawn branches for each of the buildTypes. Each branch completes a build and associated test for the type.
	// The hwhsm tests consist of both token tests {schsm, bnse} in parallel, they share a common build (hwhsm).
	activeBuildTypes.each { buildtype ->
		branches["${buildtype}"] = {

			// --- Build phase (skip when starting from "Integration Tests") ---
			if (startIdx <= 1) {
				stage("Build ${buildtype}") {
				node(params.LABEL_BUILDER ?: 'worker') {
					timeout(time: 180, unit: 'MINUTES') {
					withEnv(["BUILDTYPE=${buildtype}"]) {
					try {
						dir('.manifests') {
							checkout scm
						}

						def docker_env = defineDockerImage()

						def run_args = "--user ${docker_env.builduser} -v /${env.YOCTO_MIRROR_DIR}/:/yocto_mirror --env NODE_NAME=${NODE_NAME}"

						docker_env.image.inside(run_args) {
							def doBuild = {
								env.PKI_PASSWD = params.PKI_PASSWD
								if (params.RELEASE_BUILD) {
									env.BUILD_ADDITIONAL_GUESTOSES = "y"
								}

								sh label: 'Perform Yocto build', script: """
									set -e

									if [ -n "${params.PKI_PATH}" ]; then
										echo "Using PKI at ${params.PKI_PATH}"

										ln -s ${params.PKI_PATH} "${WORKSPACE}/out-${buildtype}/test_certificates"

										if [ -n "\$PKI_PASSWD" ]; then
											export KBUILD_SIGN_PIN="\$PKI_PASSWD"
											export GYROIDOS_TEST_PASSWD_PKI="\$PKI_PASSWD"
										fi
									else
										echo "No PKI specified, new one will be generated"
									fi

									cd "${WORKSPACE}"

									echo "Patching gyroidosgeneric.bbclass for CI multiconfig dependency"
									cat >> meta-gyroidos/classes/gyroidosgeneric.bbclass <<-'BBPATCH'
									GYROIDOS_GUESTOS_MCDEPENDS ?= "mc::guestos:gyroidos-core:do_image_complete"
									do_rootfs[mcdepends] += "\${GYROIDOS_GUESTOS_MCDEPENDS}"
									BBPATCH

									. gyroidos/build/yocto/init_ws_ids.sh "out-${buildtype}" "${params.GYROID_ARCH}" "${params.GYROID_MACHINE}"

									# init_ws.sh does cd to out-${buildtype} that is why we use .. here
									if [ -n "${params.PKI_PATH}" ]; then
										bitbake-layers add-layer ../.manifests/meta-gyroidos-release
									fi

									TARGETS="mc:guestos:gyroidos-core gyroidos-cml"

									if [ "y" = "\$BUILD_ADDITIONAL_GUESTOSES" ]; then
										echo "Patching gyroidosgeneric.bbclass for additional guestos multiconfig dependencies"
										cat >> ../meta-gyroidos/classes/gyroidosgeneric.bbclass <<-'BBPATCH'
										GYROIDOS_GUESTOS_MCDEPENDS += "mc::guestos:deb:do_image_complete mc::guestos:docker-convert:do_image_complete"
										BBPATCH
										TARGETS="\$TARGETS mc:guestos:deb mc:guestos:docker-convert"
									fi

									if [ "y" = "${params.BUILD_INSTALLER}" ]; then
										echo "Patching gyroidos-installer.bb for CI multiconfig dependency on gyroidos-cml"
										cat >> ../meta-gyroidos-intel/images/gyroidos-installer.bb <<-'BBPATCH'
										GYROIDOS_CML_MCDEPENDS ?= "mc:installer::gyroidos-cml:do_image_complete"
										do_rootfs[mcdepends] += "\${GYROIDOS_CML_MCDEPENDS}"
										BBPATCH
										TARGETS="\$TARGETS multiconfig:installer:gyroidos-installer"
									fi

									echo "Building targets: \$TARGETS"
									bitbake \$TARGETS
								"""
							}

							stepBuildImage(workspace: WORKSPACE,
								manifest_path: "${WORKSPACE}/.manifests",
								manifest_name: "yocto-${params.GYROID_ARCH}-${params.GYROID_MACHINE}.xml",
								mirror_base_path: "/yocto_mirror",
								yocto_version: env.YOCTO_VERSION,
								gyroid_arch: params.GYROID_ARCH,
								gyroid_machine: params.GYROID_MACHINE,
								buildtype: buildtype,
								selector: buildParameter('BUILDSELECTOR'),
								sync_mirrors: params.SYNC_MIRRORS,
								rebuild_previous: params.REBUILD_PREVIOUS,
								buildSteps: doBuild
							)
						}
					} catch (e) {
						completedBuilds.put(buildtype, e)
						throw e
					} finally {
						completedBuilds.putIfAbsent(buildtype, null)
						doCleanup()
					}
					} // withEnv
					} // timeout
				} // node
				} // stage
			} else {
				completedBuilds.put(buildtype, null)
			}

			// --- Test phase (skip during release builds) ---
			if (!params.RELEASE_BUILD && buildtype == 'hwhsm') {
				stage("Test hwhsm") {
					parallel(['schsm', 'bnse'].collectEntries { testtype ->
						["Test ${buildtype} [${testtype.toUpperCase()}]": {
							node(params.LABEL_TOKENTEST ?: 'tokentest') {
								timeout(time: 60, unit: 'MINUTES') {
								try {
									dir('.manifests') {
										checkout scm
									}

									def hsm = hsmEnvs[testtype]()

									stepIntegrationTest(workspace: "${WORKSPACE}",
										manifest_path: "${WORKSPACE}/.manifests",
										source_tarball: "sources-${params.GYROID_ARCH}-${params.GYROID_MACHINE}.tar",
										gyroid_machine: params.GYROID_MACHINE,
										buildtype: "hwhsm-${testtype}",
										artifact_buildtype: 'hwhsm',
										test_mode: "ccmode",
										selector: buildParameter('BUILDSELECTOR'),
										stage_name: STAGE_NAME,
										hsm_serial: hsm.serial,
										hsm_vid: hsm.vid,
										hsm_pid: hsm.pid,
										hsm_pin: hsm.pin)
								} finally {
									doCleanup()
								}
								} // timeout
							} // node
						}]
					})
				}
			} else if (!params.RELEASE_BUILD) {
				stage("Test ${buildtype}") {
				node(params.LABEL_TESTER ?: 'tester') {
					timeout(time: 60, unit: 'MINUTES') {
					try {
						dir('.manifests') {
							checkout scm
						}

						def docker_env = defineDockerImage()
						def run_args = "--user ${docker_env.builduser} --device=/dev/kvm -p 2222 -p 5901 --env NODE_NAME=${NODE_NAME} --env KVM_GID=${docker_env.kvmgid}"

						docker_env.image.inside(run_args) {
							stepIntegrationTest(workspace: "${WORKSPACE}",
								manifest_path: "${WORKSPACE}/.manifests",
								source_tarball: "sources-${params.GYROID_ARCH}-${params.GYROID_MACHINE}.tar",
								gyroid_machine: params.GYROID_MACHINE,
								buildtype: buildtype,
								test_mode: testModes[buildtype] ?: buildtype,
								selector: buildParameter('BUILDSELECTOR'),
								stage_name: STAGE_NAME,
								hsm_serial: "",
								hsm_vid: "",
								hsm_pid: "",
								hsm_pin: "",
								extra_opts: (extraOpts[buildtype] ?: ''))
						}
					} finally {
						doCleanup()
					}
					} // timeout
				} // node
				} // stage
			}
		}
	}

	if (params.SYNC_MIRRORS == 'y' && startIdx <= 1) {
		parallel(
			'Builds and Tests': {
				parallel branches
			},
			'SSH Mirror Sync': {
				def allBuildsOk = true
				stage("Waiting for Builds") {
					waitUntil(initialRecurrencePeriod: 1000, quiet: true) {
						completedBuilds.keySet().containsAll(activeBuildTypes)
					}
					if (completedBuilds.any { k, v -> v != null }) {
						echo "Not all builds succeeded, skipping mirror sync"
						allBuildsOk = false
					}
				}

				if (allBuildsOk) {
				stage("Sync Mirror") {
				node(params.LABEL_BUILDER ?: 'worker') {
					timeout(time: 60, unit: 'MINUTES') {
					try {
						lock('mirror-sync') {
							catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
								sh "ssh -o StrictHostKeyChecking=accept-new root@localhost"
							}
						}
					} finally {
						doCleanup()
					}
					} // timeout
				} // node
				} // stage
				} // if allBuildsOk
			}
		)
	} else {
		parallel branches
	}
} // stage('Build & Test')


/*TODO deploy the development and production images on separate machines
  and start demo applications inside them (e.g. a webserver)*/
//stage('Live Deployment') {}


//stage('Documentation Generation') {}

// vim: ts=4
